# Phase G: PiP-Live-Anzeige fuer Stromer

Status: Doku-Phase, keine Implementierung.  
Datum: 2026-05-13.  
Scope: privater Sideload-/PoC-Pfad; kein App-Store- oder TestFlight-Entscheid.

## Quellenstand

- Apple: [`AVPictureInPictureController`](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller), abgerufen 2026-05-13.
- Apple: [`AVPictureInPictureController.ContentSource`](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller/contentsource-swift.class), abgerufen 2026-05-13.
- Apple: [`init(sampleBufferDisplayLayer:playbackDelegate:)`](https://developer.apple.com/documentation/avkit/avpictureinpicturecontroller/contentsource-swift.class/init%28samplebufferdisplaylayer%3Aplaybackdelegate%3A%29), abgerufen 2026-05-13.
- Apple: [`AVPictureInPictureSampleBufferPlaybackDelegate`](https://developer.apple.com/documentation/avkit/avpictureinpicturesamplebufferplaybackdelegate), abgerufen 2026-05-13.
- Apple: [`AVSampleBufferDisplayLayer`](https://developer.apple.com/documentation/avfoundation/avsamplebufferdisplaylayer), abgerufen 2026-05-13.
- Apple: [`CMSampleBufferCreateForImageBuffer`](https://developer.apple.com/documentation/coremedia/cmsamplebuffercreateforimagebuffer%28allocator%3Aimagebuffer%3Adataready%3Amakedatareadycallback%3Arefcon%3Aformatdescription%3Asampletiming%3Asamplebufferout%3A%29), abgerufen 2026-05-13.
- Apple: [`CMSampleBufferCreateReadyWithImageBuffer`](https://developer.apple.com/documentation/coremedia/cmsamplebuffercreatereadywithimagebuffer%28allocator%3Aimagebuffer%3Aformatdescription%3Asampletiming%3Asamplebufferout%3A%29), abgerufen 2026-05-13.
- Apple: [`CVPixelBufferCreate`](https://developer.apple.com/documentation/corevideo/cvpixelbuffercreate%28_%3A_%3A_%3A_%3A_%3A_%3A%29), abgerufen 2026-05-13.
- Apple: [`CMVideoFormatDescriptionCreateForImageBuffer`](https://developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreateforimagebuffer%28allocator%3Aimagebuffer%3Aformatdescriptionout%3A%29), abgerufen 2026-05-13.
- Apple: [`ImageRenderer.uiImage`](https://developer.apple.com/documentation/swiftui/imagerenderer/uiimage), abgerufen 2026-05-13.
- Apple: [`ImageRenderer.cgImage`](https://developer.apple.com/documentation/swiftui/imagerenderer/cgimage), abgerufen 2026-05-13.
- Apple: [Configuring your app for media playback](https://developer.apple.com/documentation/AVFoundation/configuring-your-app-for-media-playback), abgerufen 2026-05-13.
- Apple: [`AVAudioSession.Category.playback`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback), abgerufen 2026-05-13.
- Apple: [`AVAudioSession.CategoryOptions.mixWithOthers`](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions/1616611-mixwithothers), abgerufen 2026-05-13.
- Apple: [`UIBackgroundModes`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/UIBackgroundModes), abgerufen 2026-05-13.
- Apple: [Core Bluetooth Background Processing for iOS Apps](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html), archivierte Doku, abgerufen 2026-05-13.
- Apple Developer Forums: [Background scanning for Bluetooth advertisements with LiveActivities on ios26](https://developer.apple.com/forums/thread/815189), erstellt Feb. 2026, Apple Engineer-Antwort Feb. 2026.
- Apple WWDC21: [What's new in AVKit](https://developer.apple.com/videos/play/wwdc2021/10290/), 2021-06.
- Apple WWDC22: [Create a great video playback experience](https://developer.apple.com/videos/play/wwdc2022/10147/), 2022-06.
- Apple WWDC22: [Discover advancements in iOS camera capture](https://developer.apple.com/videos/play/wwdc2022/110429/), 2022-06.
- Apple: [Adopting Picture in Picture in a Custom Player](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-custom-player), abgerufen 2026-05-13.
- Apple: [Adopting Picture in Picture for video calls](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-for-video-calls), abgerufen 2026-05-13.
- Referenzimplementierung: [getsidetrack/swiftui-pipify](https://swiftpackageregistry.com/getsidetrack/swiftui-pipify), Paketstand 2022-07-07 / Registry-Stand 2024-11-13.
- Stack Overflow: [iOS Bluetooth Low Energy Scan in Background](https://stackoverflow.com/questions/46723629/ios-bluetooth-low-energy-scan-in-background-swift3), gefragt 2017-10-13, beantwortet 2018-12-18.

## 1. APIs und iOS-Versionsanforderungen

- Das App-Target und die Swift Packages sind bereits auf iOS 17+ ausgerichtet (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `Package.swift` mit `.iOS(.v17)`).
- `AVPictureInPictureController` ist die zentrale Steuereinheit fuer Start, Stop, Status und Delegate-Events des PiP-Fensters.
- Fuer Stromer ist nicht `AVPlayerLayer`, sondern `AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)` relevant.
- Apple beschreibt `ContentSource` als Quelle fuer PiP-Inhalte aus `AVPlayerLayer`, `AVSampleBufferDisplayLayer` oder Video-Call-Content.
- WWDC21 dokumentiert den neuen Content-Source-Pfad und die Unterstuetzung fuer `AVSampleBufferDisplayLayer`; damit ist Custom-PiP ohne gebuendeltes Video moeglich.
- WWDC22 wurde geprueft: Die relevante PiP-Ergaenzung fuer Stromer bleibt WWDC21/Custom-Player plus Video-Call-Doku; WWDC22 liefert eher System-Player-, Kamera- und Multitasking-Kontext.
- `AVSampleBufferDisplayLayer` zeigt komprimierte oder unkomprimierte Video-Frames an; fuer Stromer soll es unkomprimierte UI-Frames bekommen.
- Apple markiert `AVSampleBufferDisplayLayer.enqueue(_:)` auf aktuellen Plattformen als discouraged/deprecated und verweist auf `sampleBufferRenderer.enqueueSampleBuffer`. Fuer iOS 17+ sollte der Prototyp diesen Renderer-Pfad pruefen.
- `AVPictureInPictureControllerDelegate` muss mindestens Lifecycle-Events behandeln: `willStart`, `didStart`, `failedToStart`, `willStop`, `didStop`.
- `startPictureInPicture()` fuehrt laut Apple zu `willStart`/`didStart`; bei Fehlern kommt `failedToStart`, bei User- oder System-Stop `willStop`/`didStop`.
- `AVPictureInPictureSampleBufferPlaybackDelegate` ist fuer Playback-Zustand und PiP-Controls verantwortlich, weil kein `AVPlayer` die Timeline verwaltet.
- Relevante Sample-Buffer-Delegate-Methoden: `setPlaying`, `didTransitionToRenderSize`, `skipByInterval`, `pictureInPictureControllerTimeRangeForPlayback`, `pictureInPictureControllerIsPlaybackPaused`.
- `pictureInPictureControllerShouldProhibitBackgroundAudioPlayback` ist optional relevant, falls die stille Live-Anzeige keine Audio-Continuation signalisieren soll.
- `ImageRenderer` kann SwiftUI-Views in `UIImage` oder `CGImage` rasterisieren. Die Referenzimplementierung Pipify setzt auf SwiftUI 4/iOS 16+; Stromer iOS 17+ ist damit ausreichend.
- CoreMedia/CoreVideo-Bausteine: `CVPixelBufferCreate`, `CMVideoFormatDescriptionCreateForImageBuffer`, `CMSampleBufferCreateReadyWithImageBuffer` oder `CMSampleBufferCreateForImageBuffer`.
- Ergebnis: Alle fuer einen SwiftUI-zu-PiP-Frame-Stream benoetigten APIs sind im vorhandenen iOS-17-Ziel verfuegbar.

## 2. Info.plist-Aenderungen

- Aktueller Stand: `UIBackgroundModes` enthaelt nur `bluetooth-central`.
- Fuer PiP muss `UIBackgroundModes` um `audio` ergaenzt werden. Apple benennt diese Capability als "Audio, AirPlay, and Picture in Picture".
- Apple schreibt in der Media-Playback-Doku, dass Background-Audio und PiP diese Background-Mode-Konfiguration benoetigen.
- `bluetooth-central` bleibt bestehen, weil BLE-Scanning weiterhin ueber CoreBluetooth laeuft.
- `NSBluetoothAlwaysUsageDescription` ist bereits vorhanden und bleibt fachlich passend.
- AVAudioSession-Konfiguration ist keine Plist-Aenderung, sondern Code-Verhalten des spaeteren Prototyps.
- Empfohlene Session: `AVAudioSession.Category.playback`, weil Apple diese Kategorie fuer Media Playback und Background-Audio nennt.
- Empfohlene Option: `.mixWithOthers`, weil Apple dokumentiert, dass `playback` sonst nicht mixable ist und andere Sessions unterbrechen kann.
- Kein `playAndRecord`: Stromer nimmt kein Audio auf; diese Kategorie wuerde unnoetige Mikrofon-/Routing-Semantik einfuehren.
- OPEN QUESTION: Reicht fuer einen SampleBuffer-PiP ohne echten Ton `playback + mixWithOthers`, oder verlangt iOS auf bestimmten Geraeten einen aktiven, aber stummen Audio-Track? Nur Device-Test klaert.

## 3. Video-Quelle: SwiftUI-View zu CMSampleBuffer-Stream

- Gewaehlter Zielpfad: SwiftUI-View `PipLiveDashboard` wird periodisch in Frames gerendert und als SampleBuffer an PiP gegeben.
- Pipeline-Skizze: `PipLiveDashboard` liest aktuelle Werte, `ImageRenderer` rasterisiert, `CGImage` wird in `CVPixelBuffer` gezeichnet, daraus entsteht ein `CMSampleBuffer`, der Renderer des Display-Layers bekommt das Frame.
- Render-Cadence: maximal 1 Hz und zusaetzlich bei neuen Readings; niedrigere Frequenz ist fuer SoC/Watt/Spannung/Strom/Tagesertrag ausreichend.
- `ImageRenderer.uiImage` oder `ImageRenderer.cgImage` liefert den gerasterten Inhalt; `cgImage` vermeidet einen unnoetigen UIKit-Zwischenschritt.
- `CVPixelBufferCreate` erzeugt Pixelbuffer; fuer wiederholtes Rendern sollte spaeter ein `CVPixelBufferPool` evaluiert werden.
- `CMVideoFormatDescriptionCreateForImageBuffer` erzeugt die Formatbeschreibung passend zum Pixelbuffer.
- `CMSampleBufferCreateReadyWithImageBuffer` ist fuer bereits fertige Bilddaten naheliegender als eine Variante mit Data-Ready-Callback.
- Frames sollten mit monotonen Zeitstempeln versehen werden; Referenzen wie Pipify arbeiten mit einer laufenden Medienzeit, weil PiP eine Timeline erwartet.
- Der Display-Layer muss schon vor `startPictureInPicture()` mindestens ein gueltiges Frame haben; sonst ist `isPictureInPicturePossible` typischerweise nicht stabil.
- Apple erlaubt bei `ContentSource` den Wechsel der Quelle nur, wenn die neue Quelle display-ready ist; sonst kann PiP enden.
- Alternative A, gebuendeltes MP4-Loop: technisch am einfachsten, aber zeigt keine Live-Werte und passt nicht mehr zum gewaehlten Konzept "PiP ist die Anzeige".
- Alternative B, SwiftUI-zu-CMSampleBuffer: hoechster Erkenntniswert und direkter UX-Win, weil genau die spaetere Live-Anzeige getestet wird.
- Alternative C, statisches CALayer-/CAMetalLayer-Rendering: potenziell effizienter, aber mehr Custom-Drawing und weniger Wiederverwendung der bestehenden SwiftUI-Komponenten.
- Empfehlung: Alternative B fuer Phase G-1, aber mit sehr einfachem Layout und Counter zuerst. Erst nach BLE-Erfolg lohnt ein poliertes Dashboard.
- Referenzimplementierung Pipify zeigt, dass SwiftUI-Views als Video-Stream fuer PiP machbar sind; die Library ist aber archiviert und sollte nicht ungeprueft als Dependency uebernommen werden.
- OPEN QUESTION: Welche Kombination aus Pixel-Format, Farbraum und Display-Layer-Renderer ist auf iOS 17/18/26 am stabilsten? Nur Prototyp plus Device-Test klaert.

## 4. BLE-Verhalten waehrend PiP aktiv

- Apple CoreBluetooth-Doku sagt: ohne passende Background-Ausfuehrung werden BLE-Tasks im Hintergrund bzw. suspendierten Zustand deaktiviert.
- Mit `bluetooth-central` darf eine App bestimmte zentrale BLE-Aufgaben im Hintergrund ausfuehren und wird fuer Delegate-Events geweckt.
- Dieselbe Apple-Doku beschreibt aber Einschränkungen: Duplicate-Discovery wird ignoriert, Discoveries werden zusammengefasst, und Scan-Intervalle koennen steigen.
- Apple dokumentiert fuer Background-Scanning keinen Vorrang durch `audio` oder PiP gegenueber den CoreBluetooth-Regeln.
- Apple Developer Forums, Feb. 2026: Ein Apple Engineer bestaetigt fuer iOS 26, dass ungefilterte Scans nur in ausreichend "in use"-Zustaenden ohne die harten Background-Limits laufen; bei ausgeschaltetem Lockscreen greifen wieder Limits.
- Dieselbe Apple-Antwort sagt explizit, dass es fuer diese Screen-off-Limitierung keine unterstuetzten Workarounds gibt.
- Die Live-Activity-Doku in iOS 26 ist fuer Stromer bemerkenswert, aber nicht direkt nutzbar: aktueller Zielpfad ist PiP, nicht Live Activity als Hauptanzeige.
- Community-Evidenz fuer `audio` Background Mode + BLE: Stack Overflow zeigt typische Unsicherheit; eine Antwort verweist nur auf Background Modes, nicht auf nachweisbar stabile ungefilterte Scans.
- Community-Evidenz fuer PiP + CoreBluetooth: keine belastbare Quelle gefunden, die `AVPictureInPictureController` und ungefiltertes `scanForPeripherals(withServices: nil)` ueber Stunden im Screen-off-Zustand bestaetigt.
- Ergebnis: PiP ist als sichtbare Live-Anzeige technisch plausibel, aber der BLE-Nutzen bleibt eine empirische Kernfrage.
- OPEN QUESTION: Haelt iOS eine PiP-App mit aktivem SampleBuffer-Stream in einem Zustand, in dem ungefilterte Manufacturer-Data-Scans weiterlaufen? Nur Device-Test klaert.
- OPEN QUESTION: Unterscheidet iOS zwischen sichtbarem PiP ueber anderer App, Lockscreen sichtbar und Lockscreen schwarz? Apple-Forum-Evidenz legt Unterschiede nahe; nur Device-Test mit Stromer klaert.

## 5. UX-Konzept

- Einstieg: prominenter Button im `DashboardView`, Label sinngemaess "Live-Modus starten".
- Sekundaerer Einstieg: Settings-Option "Live-Modus beim App-Start anbieten" oder "Auto-Start beim App-Start", nicht automatisch beim Backgrounding.
- Kein Auto-Start beim App-Backgrounding als Default: Das PiP-Fenster soll eine bewusste User-Aktion sein.
- Wenn der User PiP schliesst: Live-Modus endet sofort, Renderer stoppt, PiP-Service deaktiviert sich, App faellt ins normale Background-Verhalten zurueck.
- Wenn das System PiP beendet, etwa durch FaceTime oder anderes PiP-Video: gleicher Zustand wie User-Stop, mit sichtbarem Status beim naechsten App-Foreground.
- Das bestehende StromerWidget bleibt als sekundaerer Pfad erhalten, wird aber in Phase G nicht veraendert.

### Layout-Optionen fuer das PiP-Fenster

| Option | Skizze | Pro | Contra |
| --- | --- | --- | --- |
| A: Fokuswert | Zeile 1: SoC gross; Zeile 2: Watt + Alter | Sehr gut lesbar in kleinem PiP | Weniger Solar-/DC-DC-Kontext |
| B: Energie-Stack | Zwei bis vier kompakte Device-Zeilen mit Icon, Name, Wert | Mehrere Victron-Geraete sichtbar | Gefahr zu kleiner Typografie |
| C: Solar-first | Zeile 1: aktuelle Leistung; Zeile 2: Tagesertrag + Batterie | Passt zu Stromer als Energie-Monitor | Batterie-Status weniger dominant |

- Empfehlung fuer G-1: Option A mit Debug-Counter, weil Lesbarkeit und Testbarkeit wichtiger sind als Vollstaendigkeit.
- Empfehlung nach BLE-Erfolg: Option B fuer mehrere Devices, aber nur mit dynamischer Reduktion auf PiP-Groesse aus `didTransitionToRenderSize`.

## 6. Architektur-Skizze

- Neue Sinneinheit im App-Target: `PipLiveDisplayService`.
- Verantwortungen: PiP-Controller halten, SampleBuffer-Display-Layer verwalten, Playback-Delegate bereitstellen, SwiftUI-Frames rendern, Start/Stop-Status publizieren.
- `StromerAppViewModel` verwaltet den Service-Lifecycle, weil dort Scanner-/Store-nahe App-Zustaende zusammenlaufen.
- Der Service liest aktuelle Werte nicht direkt aus BLE, sondern aus bestehendem Store-/Snapshot-Zustand.
- `ScannerService` bleibt konzeptionell unveraendert. PiP beeinflusst den iOS-Lifecycle, nicht den Decoder oder Scan-Filter.
- `AppGroupReadingStore` bleibt die gemeinsame Persistenz fuer neue Reads und Debug-Counter.
- `PipLiveDashboard` ist eine kleine SwiftUI-View, getrennt von `StromerWidget`, aber visuell an dessen kompakte Informationsdichte angelehnt.
- Renderer-Komponente: `PipFrameRenderer`, zustaendig fuer SwiftUI-zu-`CGImage`/`CVPixelBuffer`/`CMSampleBuffer`.
- Throttling: maximal ein Frame pro Sekunde; bei mehreren BLE-Bursts wird nur das neueste Reading gerendert.
- Fehlerzustand: Wenn `isPictureInPictureSupported` oder `isPictureInPicturePossible` false ist, bleibt der Button disabled oder zeigt einen kurzen Status.
- Settings: `liveModeEnabled` als manuelle Laufzeit-Option, `offerLiveModeOnLaunch` als spaetere Komfortoption, `pipDebugOverlayEnabled` fuer PoC-Metriken.
- Keine neue Package-Abhaengigkeit in G-1. Pipify dient als Referenz, nicht als eingeplante Dependency.

## 7. Empirischer Test-Plan

- Phase G-1 Minimal-PoC: leeres/kompaktes PiP mit Textwerten "PiP laeuft seit X s" und "BLE-Reads gesamt Y".
- Der Counter kommt aus `AppGroupReadingStore` oder einem kleinen AppGroup-Debugwert, damit App und PiP denselben Zustand beobachten.
- Testgeraete: mindestens ein echtes iPhone mit iOS 17/18 und, falls verfuegbar, ein iOS-26-Geraet wegen Apples neuer Live-Activity-/CoreBluetooth-Aussagen.
- Testobjekte: mindestens ein echtes Victron Instant-Readout-Geraet mit bekannter Advertise-Cadence und gueltigem Key.
- Szenario A: Phone gesperrt, PiP aktiv, Screen bleibt sichtbar oder wird regelmaessig geweckt. Erwartung: BLE kann laufen; Ergebnis offen.
- Szenario B: Phone gesperrt, PiP aktiv, Screen schwarz. Erwartung: hoechstes Risiko; Apple-Forum zu iOS 26 legt nahe, dass BLE stoppt oder stark limitiert wird.
- Szenario C: Phone entsperrt, andere App offen, PiP aktiv. Erwartung: beste Chance fuer laufende Reads, weil PiP sichtbar und App-Nutzung plausibel ist.
- Szenario D: Phone entsperrt, Stromer im Foreground, kein PiP. Erwartung: Kontrollfall, BLE laeuft wie bisher.
- Szenario E: Phone gesperrt, kein PiP. Erwartung: Kontrollfall fuer aktuelles Standard-Background-Verhalten, vermutlich keine verlaesslichen Reads.
- Beobachtungsdauer: 1 h, 4 h, 12 h je Szenario, sofern der 1-h-Test nicht schon eindeutig scheitert.
- Metriken: letzte Reading-Zeit, Reads pro 10 Minuten, Lueckenlaenge, PiP-Status, App-Lifecycle-Status, Akkustand Start/Ende, Thermal State wenn verfuegbar.
- Erfolgsminimum: Im Szenario C muessen ueber 1 h regelmaessige Reads eintreffen; sonst ist PiP als Live-Anzeige ausserhalb der App zu schwach.
- Starkes Erfolgskriterium: Szenario B liefert ueber 4 h ohne manuelles Wecken weitere Reads.
- Abbruchkriterium: Wenn nach 1 h gesperrt mit aktivem PiP keine neuen Reads eintreffen, ist PiP fuer BLE-Screen-off wertlos und Plan-Wechsel auf Bridge wird reaktiviert.
- Nach erfolgreichem G-1: erst dann Layout-Option B/C, bessere Fehlertexte, Settings und Akku-Messung vertiefen.

## 8. Open Questions

- OPEN QUESTION: Funktioniert ungefiltertes Victron-BLE-Scanning im PiP-Background-State zuverlaessig genug fuer eine Live-Anzeige?
- OPEN QUESTION: Stoppt iOS das BLE-Scanning, sobald der Lockscreen schwarz wird, auch wenn PiP aktiv ist?
- OPEN QUESTION: Haelt iOS einen Custom-`AVSampleBufferDisplayLayer`-PiP ueber 4 h oder 12 h am Leben, wenn nur 1-Hz-Frames mit stiller Anzeige kommen?
- OPEN QUESTION: Muss ein echter Audio-Track laufen, oder reicht `AVAudioSession.Category.playback` plus sichtbarer PiP-SampleBuffer-Stream?
- OPEN QUESTION: Welche Delegate-Fehler treten auf echten Devices auf, wenn FaceTime, ein anderes PiP-Video oder ein Telefonat unser PiP verdrängt?
- OPEN QUESTION: Wie hoch ist der reale Stromverbrauch fuer 1-Hz-Rendering plus BLE-Scan gegenueber reinem Foreground-Scan und gegenueber ESP32/Raspi-Bridge?
- OPEN QUESTION: Rendert `ImageRenderer` alle fuer `PipLiveDashboard` genutzten SwiftUI-Elemente stabil offscreen, inklusive Fonts, Materials und dynamischer Farben?
- OPEN QUESTION: Gibt es iOS-17/18/26-Unterschiede zwischen `AVSampleBufferDisplayLayer.enqueue(_:)` und `sampleBufferRenderer.enqueueSampleBuffer`, die fuer PiP sichtbar werden?
- OPEN QUESTION: Ist `AVPictureInPictureVideoCallViewController` fuer diesen Nicht-Call-Use-Case technisch stabiler, oder ist der reine `sampleBufferDisplayLayer`-ContentSource sauberer?
- OPEN QUESTION: Wie oft darf `WidgetCenter.reloadTimelines` parallel laufen, falls Widget als Sekundaerpfad weiter aktualisiert wird? Fuer Phase G ist das ausser Scope.
