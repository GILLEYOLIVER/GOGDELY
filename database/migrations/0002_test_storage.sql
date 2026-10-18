-- GOG-072/114, issue #33: private catalog image bucket for tests only.
-- No storage.objects policies are granted. Uploads/read require trusted
-- server-side credentials until Auth and tenant authorization are designed.
BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'gogdely-menu-testes',
    'gogdely-menu-testes',
    FALSE,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp']
);

COMMIT;
