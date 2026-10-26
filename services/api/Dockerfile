# GOGDELY API — imagem para hospedagem futura (Render ou equivalente).
# Nenhum deploy foi feito; isto é apenas a construção da imagem.
FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml README.md ./
RUN pip install --no-cache-dir build && python -m build --wheel --outdir /dist || true

COPY gogdely_api ./gogdely_api

# Instala dependências do projeto (fastapi, uvicorn, pydantic).
RUN pip install --no-cache-dir . uvicorn

# A API local usa SQLite em volume; ambientes gerenciados devem apontar
# GOGDELY_DATABASE_URL para o banco gerenciado quando existir.
ENV GOGDELY_ENV=homolog
EXPOSE 8000

CMD ["uvicorn", "gogdely_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
