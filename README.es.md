# 🏦 Banca Remota — Cuba - iPhone

**Aplicación nativa para iPhone de banca cubana mediante códigos USSD. No requiere internet.**

[Read English version](README.md)

![Plataforma](https://img.shields.io/badge/Plataforma-iOS%2016%2B-blue?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-blue?logo=xcode&logoColor=white)
![Licencia](https://img.shields.io/badge/Licencia-MIT-green)
![PRs Bienvenidos](https://img.shields.io/badge/PRs-bienvenidos-brightgreen)

> Creado para revivir la aplicación original de BancaRemota tras su desaparición.
> Crédito especial a **Henry Cruz**, creador de la versión original.

---

## 🏛️ Bancos Compatibles

| Banco | Nombre Completo |
|------|-----------|
| 🔵 **BPA** | Banco Popular de Ahorro |
| 🟢 **BANDEC** | Banco de Crédito y Comercio |
| 🔴 **BM** | Banco Metropolitano |

## ⚠️ Descargo de Responsabilidad

> [!WARNING]
> Esta es una aplicación independiente hecha por la comunidad. **No está afiliada, respaldada ni patrocinada por BPA (Banco Popular de Ahorro), BANDEC (Banco de Crédito y Comercio), ni BM (Banco Metropolitano)**.  
> Los códigos USSD y los servicios pueden cambiar en cualquier momento a discreción de las instituciones financieras.

---

## ✨ Características

- 📞 **Operaciones Bancarias** — Operaciones USSD organizadas por categoría (autenticación, saldo, transferencias, límites) para BPA, BANDEC y BM. Toca para abrir el marcador del sistema.
- ⭐ **Favoritos** — Ancla operaciones frecuentes en la pantalla principal con opción de reordenar y personalizar el color de la tarjeta.
- 💳 **Cuentas Bancarias y Facturas de Servicios** — Guarda números de tarjeta, números de contrato (electricidad, agua, gas, teléfono) y cuentas Nauta para copiar y pegar rápidamente.
- 🔑 **Bóveda Segura de Claves** — Gestor local de PIN y contraseñas protegido tras autenticación biométrica (Face ID / Touch ID).
- 🔔 **Recordatorios Locales** — Programa notificaciones configurables para pagos de servicios, recargas y transferencias con acción de marcado en 1 toque.
- 🌗 **Personalización y Ajustes** — Modo Claro/Oscuro, selector de color de acento, tiempo de espera de sesión biométrica y conmutadores de accesos directos en pantalla de inicio.

### Próximamente
-  **Tipos de Cambio de Moneda y Widget** — Tasas de cambio de moneda en vivo/cacheadas (USD, EUR, MLC vs. CUP) vía API REST con widgets dedicados para Pantalla de Inicio y Bloqueo en WidgetKit. Consulta [#1](https://github.com/albertolicea00/BancaRemota/issues/1) para las especificaciones planificadas.

---

## 🔒 Privacidad

- 📵 No requiere conexión a internet
- 🚫 Sin servidores, sin cuentas de usuario, sin analíticas
- 📱 Todos los datos se almacenan localmente en el dispositivo (UserDefaults)
- 🔐 Sección de claves bloqueada tras autenticación biométrica
- 🛡️ Los datos **nunca** salen del dispositivo

---

## 🚀 Primeros Pasos

**Requisitos:** iOS 16.0+ · Xcode 15.0+

```bash
git clone https://github.com/albertolicea00/BancaRemota_app.git
open BancaRemota.xcodeproj
```

> **Nota:** `BancaRemota` gestiona su proyecto Xcode de forma nativa a través de `BancaRemota.xcodeproj` sin usar XcodeGen ni generadores de proyectos externos.

1. Configura tu cuenta de desarrollador en **Signing & Capabilities**
2. Compila y ejecuta en un dispositivo físico con `Cmd+R`

---

## 🗂️ Estructura del Proyecto

| Archivo | Descripción |
|------|-------------|
| `codes.json` | Bancos, categorías y códigos USSD. Edítalo para añadir operaciones sin tocar código. |
| `Models.swift` | Modelos `Codable` para `codes.json` y datos de usuario (`BankAccount`, `NautaAccount`, `Bill`, `UserKey`, `Reminder`, `ReminderTemplate`). |
| `Services.swift` | Carga de configuración, marcador USSD, gestión de favoritos, persistencia de datos y programación de recordatorios (`ReminderManager`, notificaciones locales). |
| `Views.swift` | Todas las pantallas: navegación, listas, formularios de edición y vistas de información. |
| `UIComponents.swift` | Componentes reutilizables: `TopNavBar`, `OperationCard`, `WalletCard`, `DataCard`, `MenuShortcutCard`, etc. |
| `BancaRemotaApp.swift` | Punto de entrada de la app, gestión de autenticación y preferencias de tema. |

Para un desglose técnico más profundo (flujo de datos, persistencia, cifrado, modelo de navegación), consulta [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 🚧 Limitaciones Conocidas

- **Sin integración con Siri / Atajos de Voz para operaciones USSD.** Considerado previamente y eliminado a propósito. Los comandos de voz de Siri para banca por USSD no son prácticos porque las operaciones USSD casi siempre requieren autenticación (introducir un PIN/clave), lo cual no se puede ejecutar de forma cómoda o fluida mediante comandos de voz. Además, cada atajo sigue delegando la ejecución a la aplicación Teléfono del sistema con una confirmación manual de marcado `tel://`, sin ofrecer una conveniencia real frente al uso directo de la app.

- **Sandbox de seguridad de iOS y limitaciones USSD (vs. Android / Transfermóvil).** A diferencia de las apps de Android (como Transfermóvil), la rigidez de la seguridad sandbox de iOS impide que las aplicaciones de terceros intercepten, lean o analicen los diálogos de respuesta USSD, encadenen sesiones USSD multipaso automáticamente o ejecuten códigos USSD en segundo plano de manera silenciosa. Abrir un enlace USSD (`tel://`) transfiere la ejecución a la aplicación Teléfono del sistema, requiriendo interacción manual del usuario para cualquier menú o respuesta posterior.

- **Sin widget en la Pantalla de Inicio.** Considerado y deliberadamente no construido. Una extensión de WidgetKit no puede llamar a `UIApplication.shared.open`/`tel://` en absoluto (`APPLICATION_EXTENSION_API_ONLY` hace que esa API no esté disponible en ninguna extensión de app, incluidos los widgets), por lo que un widget nunca puede marcar un código USSD por sí mismo. Lo único que *podría* hacer un widget es abrir la app mediante un enlace profundo (deep link) y dejar que la app marque desde allí, pero eso añade una transición de pantalla sobre lo que ya hace desbloquear el teléfono y tocar el icono de la app, sin que ningún código llegue al marcador más rápido. No vale la pena el objetivo adicional, App Group ni la superficie de mantenimiento por cero atajo real.

- **Dispositivos físicamente dual-SIM (dos tarjetas nano-SIM).** Los modelos de iPhone vendidos en China continental, Hong Kong y Macao admiten dos tarjetas nano-SIM físicas, en lugar de la combinación nano-SIM + eSIM vendida en otros lugares. Esta app no tiene interfaz de selección de línea ni forma de forzar una llamada a través de una SIM específica; iOS no proporciona a las apps ninguna API pública para elegir qué línea realiza una llamada `tel://`/USSD; siempre sale a través de la línea que los ajustes de Teléfono del propio dispositivo marquen como predeterminada. Reconocido, no implementado.

- **Sin soporte para iPad / iPadOS para USSD.** Aunque existen modelos de iPad Cellular (con ranuras SIM físicas o eSIM), Apple bloquea por completo la ejecución de códigos USSD en iPadOS. iPadOS carece de una aplicación completa de marcado telefónico, lo que significa que los usuarios no pueden marcar códigos USSD (como `*944#` o `*966#`), activar URLs `tel://*944%23` desde apps de terceros ni recibir respuestas de red USSD.

- **Sin soporte para Apple Watch / watchOS para USSD.** De manera similar, los modelos de Apple Watch Cellular no admiten la ejecución de códigos USSD ni el marcado USSD de terceros mediante watchOS.

---

## 🤝 Contribuir

Consulta [CONTRIBUTING.md](CONTRIBUTING.md). Por favor, sigue el [Código de Conducta](CODE_OF_CONDUCT.md).

> ⚠️ **Los Issues, descripciones de PR y mensajes de commit deben escribirse en inglés.**
> La interfaz de la app está intencionalmente en español (está dirigida a usuarios cubanos). Toda la comunicación técnica sigue las convenciones en inglés.

---

*Desarrollado por @albertolicea00 · Inspirado en la aplicación original de [Henry Cruz](https://www.linkedin.com/in/henrycruzmederos)*
