# Controle de Aplicativos por Horário

Aplicativo Android desenvolvido em **Flutter + Kotlin** para controlar o acesso a outros aplicativos instalados no dispositivo, permitindo definir dias da semana e horários em que cada app ficará disponível.

## Objetivo

Muitas vezes é difícil manter o foco quando certos aplicativos estão sempre acessíveis. Este projeto resolve isso criando uma camada de bloqueio visual sobre aplicativos específicos fora do horário permitido pelo usuário.

O app **não fecha nem desinstala** os aplicativos monitorados. Ele apenas exibe uma tela de bloqueio por cima quando o app está sendo usado fora do período configurado.

## Como funciona

1. O usuário cria uma **senha** para proteger as configurações do próprio app controlador.
2. Escolhe quais **aplicativos** deseja controlar.
3. Define os **dias da semana** e o **horário permitido** de uso de cada um.
4. Fora desse período, uma tela de bloqueio é exibida sobre o aplicativo.

**Exemplo:**

```
YouTube
Segunda a sexta
18:00 às 19:00
```

| Horário | Comportamento |
|---|---|
| 09:00 | Bloqueado |
| 17:59 | Bloqueado |
| 18:00 | Liberado |
| 18:59 | Liberado |
| 19:00 | Bloqueado novamente |

## Recursos

- Senha de acesso ao app controlador (armazenada como hash, nunca em texto puro).
- Seleção de aplicativos instalados com busca e ícone.
- Configuração de múltiplos dias e horários por aplicativo.
- Edição e remoção de regras mediante autenticação.
- Tela de bloqueio exibida sobre o app fora do horário permitido.
- Liberação automática assim que o horário permitido inicia.
- Desinstalação limpa: ao remover o app, todos os bloqueios deixam de existir.

## Arquitetura

```
┌─────────────────────────────────────┐
│           FLUTTER (Dart)            │
│                                     │
│  Senha • Home • Regras • Seleção    │
│                                     │
│         MethodChannel               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│           KOTLIN (Android)          │
│                                     │
│  AccessibilityService               │
│  Detecção de app em primeiro plano  │
│  Motor de regras (app + dia + hora) │
│  Overlay de bloqueio                │
└─────────────────────────────────────┘
```

- **Flutter** cuida da interface, autenticação, configuração das regras e persistência.
- **Kotlin** detecta mudanças de app em primeiro plano via `AccessibilityService` e exibe a tela de bloqueio com `WindowManager` / Overlay.

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Interface | Flutter + Dart |
| Android nativo | Kotlin, Android SDK |
| Detecção de apps | `AccessibilityService` |
| Tela de bloqueio | `WindowManager` + `TYPE_APPLICATION_OVERLAY` |
| Comunicação | Flutter `MethodChannel` |
| Armazenamento | `SharedPreferences` + `flutter_secure_storage` |

## Permissões necessárias

O aplicativo solicita duas permissões especiais do Android:

- **Serviço de acessibilidade** — para detectar qual aplicativo está em primeiro plano.
- **Sobrepor outros aplicativos** — para exibir a tela de bloqueio sobre o app fora do horário.

Ambas são concedidas manualmente pelo usuário nas configurações do sistema.

## Como usar

1. Instale o APK no dispositivo Android.
2. Abra o aplicativo e crie uma senha.
3. Conceda as duas permissões solicitadas (acessibilidade e sobreposição).
4. Toque em **+** para adicionar uma regra.
5. Escolha o aplicativo, os dias da semana e o horário permitido.
6. Salve a regra.

A partir daí, o aplicativo será bloqueado automaticamente fora do horário configurado.

## Estrutura do projeto

```
app_controle/
├── lib/
│   ├── main.dart
│   ├── models/          # AppRule, Schedule
│   ├── screens/         # password, home, app_selection, schedule
│   └── services/        # android_service, storage, icon_storage
├── android/
│   └── app/src/main/
│       ├── kotlin/com/example/app_controle/
│       │   ├── MainActivity.kt
│       │   ├── AppBlockingService.kt
│       │   └── BlockOverlayService.kt
│       └── res/xml/
│           └── accessibility_service_config.xml
└── pubspec.yaml
```

## Build

```bash
flutter pub get
flutter build apk --release
```

O APK gerado fica em `build/app/outputs/flutter-apk/app-release.apk`.

## Estado do projeto

Versão inicial (MVP) com foco em:

- Criar senha e autenticar
- Selecionar aplicativos
- Definir dias e horários
- Bloquear fora do horário
- Editar e remover regras
- Liberar automaticamente no horário permitido

Funcionalidades futuras planejadas: múltiplos horários por app, relatórios de uso, modo estudo/trabalho/sono e bloqueio por tempo de uso.

## Licença

Uso pessoal e educacional.