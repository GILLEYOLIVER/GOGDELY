-- GOG-016/017/041/052: isolated, reversible sample data for Homologacao.
-- Run only against project vlcssgerbhbvekukpzki after confirming the schema
-- and recording a recoverable backup. Never run in production.
BEGIN;

DO $$
BEGIN
    IF (SELECT count(*) FROM auth.users) <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one pre-existing test user';
    END IF;
END;
$$;

INSERT INTO gogdely.tenants (tenant_id, name, status)
VALUES ('c95d5aca-8eea-4ad4-8b50-53117abe3f01', 'GOGDELY Loja Ficticia', 'active')
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO gogdely.branches (tenant_id, branch_id, slug, name, status)
VALUES ('c95d5aca-8eea-4ad4-8b50-53117abe3f01',
        'd3bdc553-639a-47c4-9cea-aad6a06725ea',
        'loja-ficticia-gogdely', 'Loja Ficticia GOGDELY', 'active')
ON CONFLICT (tenant_id, branch_id) DO NOTHING;

-- The sole existing Auth account is the owner only in this isolated sample.
INSERT INTO gogdely.memberships (tenant_id, user_id, role)
SELECT 'c95d5aca-8eea-4ad4-8b50-53117abe3f01', id, 'owner'
FROM auth.users
WHERE true
ON CONFLICT (tenant_id, user_id) DO NOTHING;

INSERT INTO gogdely.membership_branches (tenant_id, user_id, branch_id)
SELECT 'c95d5aca-8eea-4ad4-8b50-53117abe3f01', id,
       'd3bdc553-639a-47c4-9cea-aad6a06725ea'
FROM auth.users
WHERE true
ON CONFLICT (tenant_id, user_id, branch_id) DO NOTHING;

INSERT INTO gogdely.menu_items
    (tenant_id, branch_id, item_id, name, description, category_name,
     price_cents, image_path, available, sort_order)
VALUES
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000001','Burger da Casa','Hamburguer ilustrativo com queijo e salada.','Hamburgueres',3290,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/burger.png',true,1),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000002','Burger Duplo','Dois discos e molho da casa, apenas para demonstracao.','Hamburgueres',4290,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/burger.png',true,2),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000003','Pizza Margherita','Tomate, queijo e manjericao ilustrativos.','Pizzas',5490,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/pizza.png',true,3),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000004','Pizza da Casa','Sabor demonstrativo para testes.','Pizzas',5990,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/pizza.png',true,4),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000005','Combo Sushi','Combinado ilustrativo de sushi.','Japonesa',6490,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/sushi.png',true,5),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000006','Sushi Individual','Porcao ilustrativa.','Japonesa',3590,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/sushi.png',true,6),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000007','Refrigerante Lata','Bebida ficticia para testar o carrinho.','Bebidas',690,NULL,true,7),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000008','Agua Mineral','Bebida ficticia para testar o carrinho.','Bebidas',490,NULL,true,8),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000009','Batata Crocante','Acompanhamento ilustrativo.','Acompanhamentos',1490,'https://gogdely-pwas-homologacao.onrender.com/cliente/assets/assets/images/burger.png',true,9),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000010','Molho Especial','Adicional ilustrativo.','Acompanhamentos',390,NULL,true,10),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000011','Sobremesa da Casa','Doce ilustrativo.','Sobremesas',1690,NULL,true,11),
('c95d5aca-8eea-4ad4-8b50-53117abe3f01','d3bdc553-639a-47c4-9cea-aad6a06725ea','90100000-0000-4000-8000-000000000012','Combo Familia','Produto ficticio indisponivel para testar a gestao.','Promocoes',8990,NULL,false,12)
ON CONFLICT (tenant_id, branch_id, item_id) DO NOTHING;

COMMIT;
