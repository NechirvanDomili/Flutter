# Innovation Lab Anamnesis App

Diese Flutter-App analysiert ein Patienteninterview-Transkript mit der OpenAI GPT-4.1 API und füllt ein strukturiertes Anamneseformular.

## Nutzung

1. Installiere die Abhängigkeiten:
   ```bash
   flutter pub get
   ```
2. Starte die App mit dem API-Key (ersetze den Platzhalter):
   ```bash
   flutter run --dart-define=OPENAI_API_KEY=DEIN_KEY
   ```
3. Füge ein Transkript in das Textfeld ein und tippe auf ✓.
4. Teile die Ergebnisse als CSV über den Share-Button.

## Fragebogen

Der Fragebogen liegt in `assets/questionnaire.json`. Ersetze den Inhalt durch die bereitgestellte FHIR-JSON-Datei.
