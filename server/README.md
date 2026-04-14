# empresa_server

Servidor REST do controle de produção da serigrafia.

## Rodar em desenvolvimento

```bash
cd server
dart pub get
dart run bin/server.dart
```

Servidor sobe em `http://localhost:8080`.

Variáveis de ambiente:
- `PORT` — porta HTTP (default `8080`)
- `EMPRESA_DB` — caminho do arquivo SQLite (default `empresa.db` no diretório atual)

## Compilar para produção

```bash
dart compile exe bin/server.dart -o empresa_server
./empresa_server
```

Gera um binário standalone (~10 MB), sem dependência de Dart instalado no servidor.

## Endpoints

- `GET  /health` — status do servidor
- `GET  /pedidos` — lista pedidos. Query opcional: `status`, `cliente`
- `GET  /pedidos/<id>` — um pedido
- `POST /pedidos` — cria pedido. Obrigatórios: `cliente_nome`, `descricao`, `valor`
- `PUT  /pedidos/<id>` — atualiza pedido (campos opcionais)
- `DELETE /pedidos/<id>` — remove pedido
- `GET  /configuracoes` — lista todas as configurações
- `GET  /configuracoes/<chave>` — uma configuração
- `PUT  /configuracoes/<chave>` — atualiza valor (`{"valor": "..."}`)

## Configurações default (criadas no primeiro start)

| Chave | Valor | Descrição |
|---|---|---|
| `limite_diario` | `1200` | Limite máximo de produção em R$ por dia útil |
| `producao_sabado` | `false` | Sábado conta como dia de produção |
| `producao_domingo` | `false` | Domingo conta como dia de produção |
| `prazo_padrao_dias` | `5` | Prazo padrão em dias úteis |
| `taxa_urgencia_pct` | `25` | Taxa adicional para urgentes (%) |
| `adicional_moletom_aberto_pct` | `20` | Adicional moletom aberto (%) |
| `adicional_moletom_fechado_pct` | `60` | Adicional moletom fechado (%) |
| `matriz_gratis_acima_pcs` | `150` | Não cobrar matriz acima desta qtd |
| `matriz_padrao_40x50` | `35` | Matriz 40x50 |
| `matriz_padrao_50x60` | `45` | Matriz 50x60 |
| `lote_prefixo` | `LOTE` | Prefixo do código do lote |
| `lote_digitos` | `4` | Dígitos do código sequencial |
| `empresa_nome` | `Serigrafia Baray` | Nome da empresa |
