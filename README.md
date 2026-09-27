# Oscar Finanças

Aplicativo de finanças pessoais feito em Flutter. O código principal fica em `app/` e o servidor local de prévia web e proxy de cotações fica em `tools/`.

## Requisitos

- Flutter instalado e disponível no `PATH`
- Node.js para executar a prévia web local
- Android SDK para compilar para Android

## Executar e verificar

```powershell
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Para gerar o app Android:

```powershell
cd app
flutter build appbundle --release
```

Para servir uma versão web já compilada, volte à pasta raiz e execute:

```powershell
node tools/serve_web_preview.mjs
```

No Windows, `ABRIR_OSCAR_NO_PC.bat` inicia essa prévia depois que `app/build/web` tiver sido gerado.

## Chaves de API

Não coloque chaves ou credenciais no código nem no Git. Configure-as nas variáveis de ambiente esperadas pelo servidor local ou nos arquivos locais descritos pelo próprio `tools/serve_web_preview.mjs`. O diretório `.secrets/` e o cache local estão ignorados pelo Git.

## Conteúdo versionado

O repositório mantém o código e os recursos necessários para desenvolver e compilar o app. APKs, AABs, builds, caches, logs de QA, arquivos de assinatura, credenciais e documentos de trabalho locais ficam fora do controle de versão.

O repositório começa privado. Antes de torná-lo público, revise novamente chaves, configurações de serviços, direitos dos recursos e dados que não devem ser publicados.
