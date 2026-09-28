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

## Deploy de demonstração no Render

O `render.yaml` cria um Web Service Docker que compila o Flutter Web e executa
o servidor Node do projeto. O servidor entrega a interface e mantém no mesmo
domínio os endpoints de proxy usados pelas APIs de mercado. Não publique apenas
`app/build/web` como site estático: isso deixaria esses endpoints indisponíveis.

No Render, conecte este repositório privado, crie o Blueprint a partir de
`render.yaml` e informe as chaves solicitadas nos Environment Variables do
serviço. As chaves são marcadas como `sync: false` e não ficam no Git nem na
imagem Docker. O endpoint `/health` é usado para verificar se o servidor subiu.

O plano gratuito pode suspender o serviço após 15 minutos sem tráfego e apaga o
cache local quando reinicia. Os dados financeiros do modo web continuam no
navegador de cada pessoa; esta configuração não cria contas nem sincroniza dados
entre aparelhos. Para uma demonstração que não durma e preserve o cache do
servidor, será necessário escolher um plano pago e configurar armazenamento
persistente no Render.

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
