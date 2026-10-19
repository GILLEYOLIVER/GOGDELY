import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

import 'online_master.dart';

const hostedMaster = bool.fromEnvironment('GOGDELY_HOSTED_MASTER');

void main() => runApp(const MasterApp());

/// GOG-010/096: Master prototype. Local laboratory only: no real
/// authentication, no MFA verification and no production data (GOG-082).
class MasterApp extends StatefulWidget {
  const MasterApp({super.key});

  @override
  State<MasterApp> createState() => _MasterAppState();
}

class _MasterAppState extends State<MasterApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GOGDELY Master',
        debugShowCheckedModeBanner: false,
        theme: gogdelyTheme(Brightness.light),
        darkTheme: gogdelyTheme(Brightness.dark),
        themeMode: mode,
        home: hostedMaster
            ? const OnlineMasterShell()
            : MasterHome(
                themeMode: mode, onThemeChanged: (value) => setState(() => mode = value)),
      );
}

enum MasterPage { dashboard, companies, plans, audit, settings }

class MasterHome extends StatefulWidget {
  const MasterHome(
      {super.key, required this.themeMode, required this.onThemeChanged, this.localApi});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final LocalDemoApi? localApi;

  @override
  State<MasterHome> createState() => _MasterHomeState();
}

class _MasterHomeState extends State<MasterHome> {
  late final LocalDemoApi _localApi = widget.localApi ?? LocalDemoApi();
  Timer? _refreshTimer;
  int _refreshRequest = 0;
  bool _refreshing = false;
  bool _authenticated = false;
  String? _mfaCode;

  Map<String, dynamic>? _overview;
  List<DemoCompany> _companies = const [];
  List<DemoPlan> _plans = const [];
  List<DemoAuditEntry> _audit = const [];
  String? _localError;
  String? _updatingStore;
  MasterPage page = MasterPage.dashboard;

  @override
  void initState() {
    super.initState();
    if (localDemoEnabled && _authenticated) {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _localApi.close();
    _codeEditingController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(localDemoRefreshInterval, (_) => _refreshAll());
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    if (_refreshing) return;
    _refreshing = true;
    final request = ++_refreshRequest;
    try {
      final results = await Future.wait([
        _localApi.masterOverview(),
        _localApi.masterCompanies(),
        _localApi.masterPlans(),
        _localApi.masterAudit(),
      ]);
      if (!mounted || request != _refreshRequest) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _companies = results[1] as List<DemoCompany>;
        _plans = results[2] as List<DemoPlan>;
        _audit = results[3] as List<DemoAuditEntry>;
        _localError = null;
      });
    } catch (error) {
      if (mounted && request == _refreshRequest && _localError != '$error') {
        setState(() => _localError = '$error');
      }
    } finally {
      _refreshing = false;
    }
  }

  void _open(MasterPage target) => setState(() => page = target);

  void _logout() {
    _refreshTimer?.cancel();
    setState(() {
      _authenticated = false;
      _mfaCode = null;
    });
  }

  // ==== Login com MFA simulado (GOG-082) ====

  void _generateMfaCode() {
    final code = List<int>.generate(6, (_) => Random.secure().nextInt(10)).join();
    setState(() => _mfaCode = code);
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Código MFA simulado'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                SelectableText(code,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Simulação de laboratório: nenhum e-mail ou SMS é enviado e não '
                    'há verificação de identidade real.',
                    style: TextStyle(fontSize: 12)),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendi'))
              ],
            ));
  }

  // ==== Aprovação simulada de empresas (GOG-025) ====

  Future<void> _decideCompany(DemoCompany company, bool approve) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(approve
                  ? 'Aprovar ${company.name}?'
                  : 'Recusar ${company.name}?'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Ação crítica de laboratório: registrada na trilha de auditoria '
                    'local, sem efeito em produção.',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'Motivo obrigatório')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () {
                      if (controller.text.trim().length >= 3) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    child: Text(approve ? 'Confirmar aprovação' : 'Confirmar recusa')),
              ],
            ));
    controller.dispose();
    if (reason == null || !mounted) return;
    setState(() => _updatingStore = company.storeId);
    try {
      await _localApi.masterCompanyApproval(
          storeId: company.storeId,
          actor: 'master_local',
          approve: approve,
          reason: reason);
      await _refreshAll();
    } catch (error) {
      if (mounted) setState(() => _localError = '$error');
    } finally {
      if (mounted) setState(() => _updatingStore = null);
    }
  }

  // ==== Layout ====

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOGDELY Master'),
        actions: [
          if (_authenticated) ...[
            IconButton(
                tooltip: 'Atualizar dados locais',
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip: 'Sair',
                onPressed: _logout,
                icon: const Icon(Icons.logout)),
          ],
        ],
      ),
      body: !_authenticated ? _loginBody() : _homeBody(dark),
    );
  }

  Widget _loginBody() => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.shield_outlined, size: 56, color: GogdelyColors.blue),
            const SizedBox(height: 12),
            const Text('Acesso Master',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
                'Laboratório local. Nenhuma autenticação real existe ainda: o login '
                'e o MFA abaixo são simulações visíveis para teste.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 20),
            if (_localError != null)
              Text(_localError!, style: const TextStyle(color: Colors.red)),
            FilledButton.icon(
                onPressed: _generateMfaCode,
                icon: const Icon(Icons.key),
                label: const Text('Gerar código MFA simulado')),
            const SizedBox(height: 12),
            _codeField(),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _tryAuthenticate,
                child: const Text('Entrar com MFA simulado')),
          ]),
        ),
      );

  Widget _codeField() => TextField(
        controller: _codeEditingController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
            prefixIcon: Icon(Icons.pin_outlined),
            labelText: 'Código de 6 dígitos',
            helperText: 'Digite o código exibido na simulação.'),
        onChanged: (value) => setState(() {}),
      );

  void _tryAuthenticate() {
    final controller = _codeEditingController;
    if (_mfaCode == null || controller.text.trim() != _mfaCode) {
      setState(() => _localError = 'Código MFA simulado incorreto.');
      return;
    }
    setState(() {
      _authenticated = true;
      _localError = null;
    });
    _codeEditingController.clear();
    if (localDemoEnabled) _startPolling();
  }

  late final TextEditingController _codeEditingController = TextEditingController();

  Widget _homeBody(bool dark) => Row(children: [
        NavigationRail(
          selectedIndex: page.index,
          onDestinationSelected: (index) => _open(MasterPage.values[index]),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Visão geral')),
            NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: Text('Empresas')),
            NavigationRailDestination(
                icon: Icon(Icons.card_membership_outlined),
                selectedIcon: Icon(Icons.card_membership),
                label: Text('Planos')),
            NavigationRailDestination(
                icon: Icon(Icons.policy_outlined),
                selectedIcon: Icon(Icons.policy),
                label: Text('Auditoria')),
            NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Config')),
          ],
        ),
        VerticalDivider(width: 1, thickness: 1, color: Theme.of(context).dividerColor),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: switch (page) {
                  MasterPage.dashboard => _dashboard(),
                  MasterPage.companies => _companiesPage(),
                  MasterPage.plans => _plansPage(),
                  MasterPage.audit => _auditPage(),
                  MasterPage.settings => _settingsPage(),
                })),
      ]);

  String money(int cents) =>
      'R\$ ${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')}';

  String _when(String iso) {
    final date = DateTime.tryParse(iso)?.toLocal();
    if (date == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}:${two(date.minute)}';
  }

  // ==== Páginas ====

  Widget _dashboard() => ListView(children: [
        const Text('Visão geral da plataforma',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
            'Dados do SQLite local do piloto. Nada aqui representa operação real.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        if (_localError != null)
          Text(_localError!, style: const TextStyle(color: Colors.red)),
        if (!localDemoEnabled)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Execute com GOGDELY_LOCAL_API=true e a API local no ar '
                      '(perfil F5 "GOGDELY API • Banco local") para ver os dados do piloto.'))),
        if (_overview != null) ...[
          Wrap(spacing: 10, runSpacing: 10, children: [
            _metric('Empresas aprovadas',
                '${(_overview!['companies'] as Map)['approved']}', Icons.storefront),
            _metric('Aguardando aprovação',
                '${(_overview!['companies'] as Map)['pending']}', Icons.hourglass_top),
            _metric('Pedidos ativos',
                '${(_overview!['orders'] as Map)['active']}', Icons.receipt_long),
            _metric('Volume estimado',
                money((_overview!['orders'] as Map)['gross_cents'] as int), Icons.payments),
            _metric('Pagamentos simulados',
                '${(_overview!['payments'] as Map)['simulated_count']}', Icons.payments_outlined),
            _metric('Comissão estimada',
                money((_overview!['commissions'] as Map)['estimated_cents'] as int),
                Icons.percent),
          ]),
          const SizedBox(height: 12),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Avisos obrigatórios',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('${(_overview!['payments'] as Map)['warning']}',
                        style: const TextStyle(fontSize: 12)),
                    Text('${(_overview!['commissions'] as Map)['warning']}',
                        style: const TextStyle(fontSize: 12)),
                  ]))),
        ],
      ]);

  Widget _metric(String label, String value, IconData icon) => SizedBox(
      width: 180,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 18, color: GogdelyColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(label,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ]))));

  Widget _companiesPage() => ListView(children: [
        Row(children: [
          const Expanded(
              child: Text('Empresas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Atualizar', onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ]),
        const Text(
            'Cadastro do laboratório. Aprovação/recusa é simulada e auditada localmente.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        if (_localError != null)
          Text(_localError!, style: const TextStyle(color: Colors.red)),
        for (final company in _companies)
          Card(
              child: ListTile(
            title: Text('${company.name} · ${company.category}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                'Plano ${company.plan?.name ?? "-"} · comissão ${company.plan?.commissionPercent ?? 0}%\n'
                'Status: ${_statusLabel(company.status)}'),
            isThreeLine: true,
            trailing: company.pending
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedButton(
                        onPressed: _updatingStore == company.storeId
                            ? null
                            : () => _decideCompany(company, false),
                        child: const Text('Recusar')),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: _updatingStore == company.storeId
                            ? null
                            : () => _decideCompany(company, true),
                        child: const Text('Aprovar')),
                  ])
                : _statusPill(_statusLabel(company.status)),
          )),
      ]);

  String _statusLabel(String status) => switch (status) {
        'approved' => 'Aprovada',
        'pending' => 'Pendente',
        'rejected' => 'Recusada',
        _ => status,
      };

  Widget _statusPill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFFDDE8FF), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: const TextStyle(
              color: GogdelyColors.blue, fontWeight: FontWeight.w700, fontSize: 11)));

  Widget _plansPage() => ListView(children: [
        const Text('Planos e comissões',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
            'Catálogo local fixo (GOG-058 a GOG-062). Nenhuma cobrança real existe; '
            'comissão estimada incide sobre produtos, sem frete.',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        for (final plan in _plans)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(plan.monthlyFeeCents > 0
                        ? 'Mensalidade: ${money(plan.monthlyFeeCents)}'
                        : 'Mensalidade: contrato personalizado'),
                    Text('Comissão sobre produtos: ${plan.commissionPercent}%'),
                    Text(plan.trialDays > 0
                        ? 'Teste gratuito: ${plan.trialDays} dias'
                        : 'Sem teste gratuito'),
                    const SizedBox(height: 6),
                    Text(plan.notes, style: const TextStyle(fontSize: 12)),
                  ]))),
      ]);

  Widget _auditPage() => ListView(children: [
        Row(children: [
          const Expanded(
              child: Text('Trilha de auditoria local',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          IconButton(
              tooltip: 'Atualizar', onPressed: _refreshAll, icon: const Icon(Icons.refresh)),
        ]),
        const Text(
            'Eventos consolidados do SQLite: pedidos, cardápio, pagamentos simulados, '
            'estoque, caixa e aprovações. Somente laboratório (GOG-038/082).',
            style: TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        if (_localError != null)
          Text(_localError!, style: const TextStyle(color: Colors.red)),
        if (_audit.isEmpty) const Text('Nenhum evento registrado neste banco local.'),
        for (final entry in _audit)
          Card(
              child: ListTile(
            leading: Icon(_sourceIcon(entry.source), color: GogdelyColors.blue),
            title: Text(entry.detail,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
                '${_sourceLabel(entry.source)} · ${entry.ref} · ${entry.actor} · ${_when(entry.createdAt)}',
                style: const TextStyle(fontSize: 11)),
          )),
      ]);

  IconData _sourceIcon(String source) => switch (source) {
        'order' => Icons.receipt_long,
        'menu' => Icons.restaurant_menu,
        'payment' => Icons.payments,
        'stock' => Icons.inventory_2,
        'pos' => Icons.point_of_sale,
        'master' => Icons.admin_panel_settings,
        _ => Icons.event_note,
      };

  String _sourceLabel(String source) => switch (source) {
        'order' => 'Pedido',
        'menu' => 'Cardápio',
        'payment' => 'Pagamento simulado',
        'stock' => 'Estoque',
        'pos' => 'Caixa',
        'master' => 'Master',
        _ => source,
      };

  Widget _settingsPage() => ListView(children: [
        const Text('Configurações',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(
            child: Column(children: [
              for (final (label, value) in [
                ('Automático', ThemeMode.system),
                ('Claro', ThemeMode.light),
                ('Escuro', ThemeMode.dark),
              ])
                ListTile(
                    title: Text(label),
                    trailing: widget.themeMode == value
                        ? const Icon(Icons.check_circle, color: GogdelyColors.blue)
                        : null,
                    onTap: () => widget.onThemeChanged(value)),
            ])),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ambiente', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('API local: ${localDemoEnabled ? localDemoBaseUrl : "desativada"}'),
                  const Text(
                      'Nenhuma credencial, MFA real, tenant autenticado ou serviço '
                      'pago está configurado. Produção exige aprovação do proprietário.',
                      style: TextStyle(fontSize: 12)),
                ]))),
      ]);
}
