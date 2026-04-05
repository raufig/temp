# PetalGemini — Guía de Configuración y Pruebas

## Requisitos Previos

### Para el Phone Service (Android)
- Android Studio Hedgehog (2023.1) o superior
- JDK 17
- Dispositivo Android con Android 8.0+ (API 26)
- Cuenta de Huawei Developer ([enlace al portal](https://developer.huawei.com/consumer/en/))
- Cuenta de Google AI Studio para la API key de Gemini

### Para el Watch App (HarmonyOS)
- DevEco Studio 4.0 o superior (IDE oficial de Huawei para HarmonyOS)
- Huawei Watch GT 6 con HarmonyOS 4.0+
- Cable de depuración o conexión WiFi para debug en el reloj

---

## Parte 1 — Configurar el Phone Service (Android)

### 1.1 Obtener la API Key de Gemini

1. Ve a [Google AI Studio](https://aistudio.google.com/apikey)
2. Inicia sesión con tu cuenta de Google
3. Haz clic en **"Create API Key"**
4. Copia la key generada (empieza con `AIza...`)
5. Guárdala en un lugar seguro — la usarás al abrir la app en el teléfono

> **Tier gratuito:** 15 requests/minuto, 1M tokens/día. Más que suficiente para uso personal.

### 1.2 Configurar Huawei Wear Engine SDK

1. Regístrate en [Huawei Developer Console](https://developer.huawei.com/consumer/en/service/josp/agc/index.html)
2. Crea un nuevo proyecto y una app Android
3. Activa el servicio **Wear Engine** en la consola:
   - AppGallery Connect → Mi proyecto → Gestión de API → Wear Engine → Activar
4. Descarga el archivo `agconnect-services.json`
5. Colócalo en `phone-service/app/`
6. Edita `AndroidManifest.xml` y reemplaza `YOUR_HMS_APP_ID` con tu App ID real:
   ```xml
   <meta-data
       android:name="com.huawei.hms.client.appid"
       android:value="appid=TU_APP_ID_REAL" />
   ```

### 1.3 Configurar repositorio Maven de Huawei

Crea el archivo `phone-service/settings.gradle.kts`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolution {
    repositories {
        google()
        mavenCentral()
        // Repositorio de Huawei para Wear Engine SDK
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
}

rootProject.name = "PetalGemini"
include(":app")
```

### 1.4 Agregar archivo `gradle.properties`

Crea `phone-service/gradle.properties`:

```properties
android.useAndroidX=true
android.enableJetifier=true
org.gradle.jvmargs=-Xmx2048m
```

### 1.5 Agregar archivo root `build.gradle.kts`

Crea `phone-service/build.gradle.kts` (nivel raíz, renombrar el actual a `app/build.gradle.kts`):

```kotlin
plugins {
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.20" apply false
    id("com.google.devtools.ksp") version "1.9.20-1.0.14" apply false
}
```

> **Nota:** El `build.gradle.kts` que ya existe debe moverse a `phone-service/app/build.gradle.kts`.

### 1.6 Agregar recursos faltantes

Necesitas crear estos archivos de recursos que el código referencia:

**`phone-service/app/src/main/res/drawable/ic_launcher.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#00C853"
        android:pathData="M54,54m-40,0a40,40 0,1 1,80 0a40,40 0,1 1,-80 0" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M42,40L54,65L66,40"
        android:strokeWidth="3"
        android:strokeColor="#FFFFFF" />
</vector>
```

**`phone-service/app/src/main/res/drawable/ic_notification.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,16l-4,-5h3V8h2v3h3l-4,5z" />
</vector>
```

### 1.7 Compilar y probar el Phone Service solo

Este es el **paso 1 del orden de desarrollo recomendado**: probar Gemini desde el teléfono sin reloj.

1. Abre `phone-service/` en Android Studio
2. Sincroniza Gradle
3. Conecta tu teléfono Android por USB (o usa emulador)
4. Ejecuta la app
5. Pega tu API key de Gemini en el campo de texto
6. Toca **"Iniciar servicio"**
7. Verifica en Logcat (filtro: `PetalGeminiService`) que el servicio arranca sin errores

**Para probar Gemini sin el reloj**, crea un test unitario temporal:

Crea `phone-service/app/src/test/java/com/petalgemini/GeminiTest.kt`:

```kotlin
package com.petalgemini

import com.petalgemini.gemini.GeminiClient
import com.petalgemini.util.ResponseFormatter
import kotlinx.coroutines.runBlocking
import org.junit.Test

class GeminiTest {
    
    // Reemplaza con tu API key real para probar
    private val apiKey = "TU_API_KEY_AQUI"
    
    @Test
    fun testGeminiBasicQuery() = runBlocking {
        val client = GeminiClient(apiKey)
        val result = client.ask("Convierte 5 millas a kilómetros")
        
        assert(result.isSuccess) { "Gemini debería responder exitosamente" }
        println("Respuesta: ${result.getOrNull()}")
        
        val formatted = ResponseFormatter.formatForWatch(result.getOrNull()!!)
        println("Formateado: $formatted")
        assert(formatted.length <= 200) { "Respuesta debe caber en 200 chars" }
    }
    
    @Test
    fun testResponseFormatter() {
        val input = "La temperatura es de 23 grados Celsius y la distancia es de 8 kilómetros"
        val result = ResponseFormatter.compactNumbers(input)
        assert(result.contains("23°C")) { "Debería compactar grados" }
        assert(result.contains("8km")) { "Debería compactar kilómetros" }
        println("Compactado: $result")
    }
    
    @Test
    fun testTruncation() {
        val longText = "A".repeat(300)
        val truncated = ResponseFormatter.truncate(longText)
        assert(truncated.length <= 201) { "No debe exceder 200 chars + ellipsis" }
    }
}
```

Ejecutar: `./gradlew test` desde `phone-service/`.

---

## Parte 2 — Configurar la comunicación BLE

### 2.1 Emparejar reloj con teléfono

1. Instala **Huawei Health** en tu teléfono Android desde AppGallery o Play Store
2. Empareja el GT 6 con el teléfono vía Huawei Health
3. Verifica que el reloj aparece como conectado en la app

### 2.2 Probar canal BLE con datos ficticios

Antes de tener la Watch App lista, puedes simular mensajes desde el reloj creando un test de integración:

Crea `phone-service/app/src/androidTest/java/com/petalgemini/BleIntegrationTest.kt`:

```kotlin
package com.petalgemini

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.petalgemini.ble.WearBridge
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BleIntegrationTest {

    @Test
    fun testWearBridgeInitialization() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val bridge = WearBridge(context)
        
        // Verificar que se puede crear el bridge sin crash
        bridge.startListening()
        
        // Registrar listener
        bridge.onQuery { query, timestamp ->
            println("Query recibida: $query (ts=$timestamp)")
        }
        
        Thread.sleep(5000) // Esperar 5 seg para verificar en logs
        bridge.stopListening()
    }
}
```

### 2.3 Permisos en tiempo de ejecución

La primera vez que abras la app, Android pedirá estos permisos. Acéptalos todos:

- **Bluetooth** — para comunicación con el reloj
- **Ubicación** — requerida por Android para BLE + GPS contextual
- **Notificaciones** — para la notificación persistente del servicio

---

## Parte 3 — Configurar la Watch App (HarmonyOS)

### 3.1 Instalar DevEco Studio

1. Descarga [DevEco Studio](https://developer.huawei.com/consumer/en/deveco-studio/) (versión 4.0+)
2. Instálalo y configura el SDK de HarmonyOS
3. En el SDK Manager, instala:
   - HarmonyOS SDK API 9
   - Wearable SDK
   - ArkTS toolchain

### 3.2 Abrir el proyecto del reloj

1. Abre DevEco Studio
2. File → Open → selecciona la carpeta `watch-app/`
3. Espera a que sincronice el proyecto

### 3.3 Configurar firma para debug

1. File → Project Structure → Signing Configs
2. Selecciona "Automatically generate signature" para debug
3. Ingresa tu Huawei Developer ID cuando lo pida

### 3.4 Agregar el AppScope faltante

Crea `watch-app/AppScope/app.json5`:

```json5
{
  "app": {
    "bundleName": "com.petalgemini.watch",
    "vendor": "PetalGemini",
    "versionCode": 1000000,
    "versionName": "1.0.0",
    "icon": "$media:app_icon",
    "label": "$string:app_name",
    "minAPIVersion": 9,
    "targetAPIVersion": 9
  }
}
```

### 3.5 Agregar oh-package.json5

Crea `watch-app/oh-package.json5`:

```json5
{
  "name": "petalgemini-watch",
  "version": "1.0.0",
  "description": "PetalGemini Watch App for Huawei GT 6",
  "main": "",
  "author": "",
  "license": "ISC",
  "dependencies": {}
}
```

Y `watch-app/entry/oh-package.json5`:

```json5
{
  "name": "entry",
  "version": "1.0.0",
  "description": "Main entry module",
  "main": "",
  "author": "",
  "license": "ISC",
  "dependencies": {}
}
```

### 3.6 Desplegar al reloj

**Opción A — Por cable (HDC):**
1. Activa el modo desarrollador en el GT 6: Ajustes → Acerca de → toca 7 veces el número de compilación
2. Activa la depuración USB en el reloj
3. Conecta el reloj al PC con la base de carga + cable USB
4. En DevEco Studio, selecciona el dispositivo y haz clic en Run

**Opción B — Por WiFi:**
1. Activa WiFi en el reloj y conéctalo a la misma red que tu PC
2. En el reloj, ve a Ajustes → Desarrollador → Depuración de red → anota la IP
3. En DevEco Studio: Tools → Device Manager → Connect by IP
4. Ingresa `IP_DEL_RELOJ:5555` y conecta
5. Ejecuta la app

---

## Parte 4 — Prueba de Integración Completa

### 4.1 Checklist paso a paso

1. [ ] **Teléfono:** Abrir PetalGemini, ingresar API key, tocar "Iniciar servicio"
2. [ ] **Teléfono:** Verificar notificación persistente "Escuchando a tu reloj"
3. [ ] **Reloj:** Abrir PetalGemini, verificar indicador verde "Conectado"
4. [ ] **Reloj:** Tocar botón de micrófono, decir "Hola"
5. [ ] **Verificar:** El reloj muestra "Escuchando..." → "Pensando..." → respuesta de Gemini
6. [ ] **Reloj:** Preguntar "Qué clima hace" (verifica que inyecta GPS automáticamente)
7. [ ] **Reloj:** Preguntar algo de seguimiento: "Convierte 5 millas a kilómetros" y luego "Y 10?"
8. [ ] **Reloj:** Probar teclado: tocar ⌨, escribir texto, enviar
9. [ ] **Reloj:** Decir "olvida todo" y verificar que el historial se borra
10. [ ] **Teléfono:** Verificar que el historial aparece en la pantalla principal
11. [ ] **Reloj:** Apagar Bluetooth del teléfono → verificar mensaje "Sin conexión al teléfono"

### 4.2 Probar modo offline (cache)

1. Haz varias preguntas con conexión activa
2. Apaga el Bluetooth del teléfono
3. Repite una de las preguntas anteriores
4. El reloj debería mostrar la respuesta cacheada con "(cache)" al final

### 4.3 Verificar batería

Después de 30 minutos de uso:
- Revisar consumo de batería del reloj en Ajustes → Batería
- BLE debería consumir menos de 3% en ese período
- Si consume más, verificar que el canal BLE se cierra al salir de la app

---

## Parte 5 — Problemas Comunes y Soluciones

### "Sin conexión al teléfono" en el reloj
- Verifica que el reloj está emparejado en Huawei Health
- Verifica que el servicio PetalGemini está corriendo (notificación visible)
- Reinicia Bluetooth en ambos dispositivos
- Verifica que Wear Engine está activado en la consola de Huawei

### "Gemini no disponible"
- Verifica tu API key en Google AI Studio — ¿sigue activa?
- Verifica conexión a internet del teléfono
- Revisa Logcat con filtro `GeminiClient` para ver el error exacto
- Si ves error 429: estás excediendo 15 req/min — espera un minuto

### La app del reloj no se instala
- Verifica que el reloj tiene HarmonyOS 4.0+
- Verifica que el `minAPIVersion` en `app.json5` coincide con la versión del reloj
- Intenta reiniciar el reloj y reconectar DevEco Studio

### STT no reconoce voz
- Verifica que aceptaste el permiso de micrófono
- El idioma por defecto es `es-ES` — si hablas otro idioma, cambia el parámetro `language` en `SpeechService.ets`
- El GT 6 necesita descarga inicial del modelo STT offline — conéctalo a WiFi la primera vez

### El servicio se detiene solo
- Android puede matar ForegroundServices agresivamente en algunos fabricantes
- Ve a Ajustes del teléfono → Apps → PetalGemini → Batería → Sin restricciones
- En Huawei/Honor: Ajustes → Batería → Inicio de apps → PetalGemini → Gestión manual → todo activado

---

## Estructura Final de Archivos

```
petalgemini/
├── watch-app/                          # HarmonyOS Watch App
│   ├── AppScope/
│   │   └── app.json5                   # ← CREAR (Parte 3.4)
│   ├── build-profile.json5
│   ├── oh-package.json5                # ← CREAR (Parte 3.5)
│   └── entry/
│       ├── oh-package.json5            # ← CREAR (Parte 3.5)
│       └── src/main/
│           ├── module.json5
│           ├── ets/
│           │   ├── MainAbility.ets
│           │   ├── models/Message.ets
│           │   ├── pages/
│           │   │   ├── MainPage.ets
│           │   │   ├── HistoryPage.ets
│           │   │   └── SettingsPage.ets
│           │   └── services/
│           │       ├── BleService.ets
│           │       ├── SpeechService.ets
│           │       └── CacheService.ets
│           └── resources/base/
│               ├── element/
│               │   ├── string.json
│               │   └── color.json
│               └── profile/
│                   └── main_pages.json
│
├── phone-service/                      # Android Phone Service
│   ├── build.gradle.kts                # ← RENOMBRAR a nivel raíz (Parte 1.5)
│   ├── settings.gradle.kts             # ← CREAR (Parte 1.3)
│   ├── gradle.properties               # ← CREAR (Parte 1.4)
│   ├── proguard-rules.pro
│   └── app/
│       ├── build.gradle.kts            # ← MOVER el actual aquí (Parte 1.5)
│       ├── agconnect-services.json     # ← DESCARGAR de Huawei (Parte 1.2)
│       └── src/
│           ├── main/
│           │   ├── AndroidManifest.xml
│           │   ├── java/com/petalgemini/
│           │   │   ├── PetalGeminiApp.kt
│           │   │   ├── MainActivity.kt
│           │   │   ├── ble/WearBridge.kt
│           │   │   ├── db/ConversationDatabase.kt
│           │   │   ├── gemini/GeminiClient.kt
│           │   │   ├── service/PetalGeminiService.kt
│           │   │   └── util/
│           │   │       ├── ContextProvider.kt
│           │   │       └── ResponseFormatter.kt
│           │   └── res/
│           │       ├── drawable/
│           │       │   ├── ic_launcher.xml   # ← CREAR (Parte 1.6)
│           │       │   └── ic_notification.xml # ← CREAR (Parte 1.6)
│           │       ├── layout/activity_main.xml
│           │       └── values/
│           │           ├── strings.xml
│           │           └── themes.xml
│           ├── test/                    # ← CREAR (Parte 1.7)
│           └── androidTest/            # ← CREAR (Parte 2.2)
│
└── docs/
    └── SETUP.md                        # ← Este archivo
```

Los archivos marcados con `← CREAR` son los que necesitas agregar manualmente siguiendo las instrucciones de cada parte.
