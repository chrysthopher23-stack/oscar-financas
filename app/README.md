# Oscar Finanças

**Clareza que transforma escolhas em patrimônio.**

Aplicativo Flutter modular de gestão financeira, ganhos extras, investimentos,
relatórios, agenda, planos, benefícios de parceiros e configurações.

## Módulos reais

1. Painel Financeiro
2. Ganho Extra
3. Investimentos
4. Relatório Geral
5. Agenda
6. Planos
7. Oscar Clube
8. Configurações

A entrada oferece Google, Apple e uso local sem conta. Google e Apple permanecem
desabilitados de forma segura em builds de publicação enquanto as credenciais
reais não forem configuradas.

## Internacionalização

- Português do Brasil (`pt-BR`) / BRL
- Inglês dos Estados Unidos (`en-US`) / USD
- Alemão da Alemanha (`de-DE`) / EUR
- Francês da França (`fr-FR`) / EUR
- Hindi da Índia (`hi-IN`) / INR

Valores monetários usam inteiros em unidades menores. A formatação de moeda,
datas e relatórios PDF respeita o idioma e a região selecionados. Fontes para
hindi são incorporadas ao app para relatórios offline.

## Arquitetura

Cada tela vive em `lib/features/screen_*` e expõe uma API pública própria.
Regras de apresentação, aplicação, domínio e dados permanecem separadas.
Compartilhamento entre telas ocorre por contratos e fachadas públicas, sem
importar detalhes internos de outro módulo.

## Verificação

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

A geração de APK exige Flutter e Android SDK configurados. Serviços de loja,
login federado, AdMob e provedores econômicos precisam de identificadores e
credenciais reais antes da publicação; o projeto não contém chaves inventadas.
