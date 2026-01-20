import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _openAiEndpoint = 'https://api.openai.com/v1/chat/completions';
const _openAiModel = 'gpt-4.1';

void main() {
  runApp(const AnamnesisApp());
}

class AnamnesisApp extends StatelessWidget {
  const AnamnesisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anamnesis Analyzer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AnamnesisHomePage(),
    );
  }
}

class AnamnesisHomePage extends StatefulWidget {
  const AnamnesisHomePage({super.key});

  @override
  State<AnamnesisHomePage> createState() => _AnamnesisHomePageState();
}

class _AnamnesisHomePageState extends State<AnamnesisHomePage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  List<AnswerItem> _answers = [];
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyzeTranscript() async {
    final transcript = _controller.text.trim();
    if (transcript.isEmpty) {
      _showSnackBar('Bitte fügen Sie ein Transkript ein.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final questionnaire =
          await rootBundle.loadString('assets/questionnaire.json');
      final apiKey = const String.fromEnvironment('OPENAI_API_KEY');
      if (apiKey.isEmpty) {
        throw Exception('OPENAI_API_KEY fehlt.');
      }

      final prompt = _buildPrompt(questionnaire, transcript);
      final response = await http.post(
        Uri.parse(_openAiEndpoint),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
        body: jsonEncode({
          'model': _openAiModel,
          'temperature': 0.2,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Du bist eine ausgebildete Pflegekraft und analysierst Patienteninterviews.'
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OpenAI Fehler ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['choices']?[0]?['message']?['content'];
      if (content == null) {
        throw Exception('Antwortformat nicht erkannt.');
      }

      final parsedAnswers = _parseAnswerJson(content.toString());
      setState(() {
        _answers = parsedAnswers;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<AnswerItem> _parseAnswerJson(String content) {
    final normalized = content.trim();
    final jsonBody = normalized.startsWith('```')
        ? normalized.replaceAll(RegExp(r'```json|```'), '').trim()
        : normalized;
    final decoded = jsonDecode(jsonBody);

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AnswerItem.fromJson)
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final list = decoded['answers'] ?? decoded['items'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(AnswerItem.fromJson)
            .toList();
      }
    }

    throw Exception('Antwort konnte nicht geparst werden.');
  }

  String _buildPrompt(String questionnaire, String transcript) {
    return '''Bitte analysiere das folgende Transkript eines Patienteninterviews.
Nutze den Fragebogen im JSON-Format, um Antworten für jede Frage zu ermitteln.
Wähle bei vorgegebenen Antwortmöglichkeiten die passendste Option.
Gib deine Antworten als JSON-Liste aus, wobei jedes Element "linkId" und "answer" enthält.

FRAGEBOGEN:
$questionnaire

TRANSKRIPT:
$transcript''';
  }

  Future<void> _exportCsv() async {
    if (_answers.isEmpty) {
      _showSnackBar('Keine Ergebnisse zum Exportieren.');
      return;
    }

    final rows = <List<String>>[
      ['linkId', 'answer'],
      ..._answers.map((item) => [item.linkId, item.answer]),
    ];
    final csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/anamnesis_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)],
        text: 'Anamnese-Export');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1B6FA8)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Als CSV teilen',
            onPressed: _loading ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Analyse starten',
            onPressed: _loading ? null : _analyzeTranscript,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Schreibe oder spreche deinen Text hier ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 6),
                    )
                  : _answers.isEmpty
                      ? const Center(
                          child: Text('Keine Ergebnisse vorhanden.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _answers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = _answers[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.linkId,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.answer,
                                          style: const TextStyle(
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Checkbox(
                                    value: false,
                                    onChanged: (_) {},
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnswerItem {
  AnswerItem({required this.linkId, required this.answer});

  final String linkId;
  final String answer;

  factory AnswerItem.fromJson(Map<String, dynamic> json) {
    return AnswerItem(
      linkId: json['linkId']?.toString() ?? 'unknown',
      answer: json['answer']?.toString() ?? 'unbekannt',
    );
  }
}
