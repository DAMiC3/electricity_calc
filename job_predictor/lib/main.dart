import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SurveyPage(),
    );
  }
}

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

enum GradeStatus {
  highSchool,
  undergradCS,
  undergradDesign,
  undergradEngineering,
  businessSchool,
  graduateResearch,
  bootcamp,
  selfTaught,
}

class _SurveyPageState extends State<SurveyPage> {
  int step = 0;

  // Step 0
  GradeStatus? grade;
  final TextEditingController institutionCtrl = TextEditingController();

  // Step 1 - Interests (multi-select)
  final Map<String, bool> interests = {
    'Coding / building software': false,
    'Design / UX / visuals': false,
    'Numbers / data': false,
    'People / teaching': false,
    'Writing / communication': false,
    'Hardware / electronics': false,
    'Business / entrepreneurship': false,
    'Science / research': false,
  };

  // Step 2 - Working style (radio for each sub-question)
  String? styleSoloTeam;
  String? styleWorkplace;
  String? styleHandsTheoretical;
  String? styleCreativityStructure;

  // Step 3 - Skills (multi-select)
  final Map<String, bool> skills = {
    'Math / statistics': false,
    'Programming': false,
    'Art / visual design': false,
    'Communication / storytelling': false,
    'Biology / chemistry': false,
    'Systems / IT / admin': false,
  };

  Map<String, int> scores = {};

  @override
  void dispose() {
    institutionCtrl.dispose();
    super.dispose();
  }

  void next() {
    if (step < 3) {
      setState(() => step++);
    } else {
      // Compute results
      final results = _computeScores();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultsPage(
            institution: institutionCtrl.text.trim(),
            grade: grade,
            top: results,
            selectionsSummary: _makeSummary(),
          ),
        ),
      );
    }
  }

  void back() {
    if (step > 0) setState(() => step--);
  }

  List<MapEntry<String, int>> _computeScores() {
    final Map<String, int> s = {
      'Software Engineer': 0,
      'Data Scientist': 0,
      'UX Designer': 0,
      'Product Manager': 0,
      'Teacher / Trainer': 0,
      'Electrical Engineer': 0,
      'Research Scientist': 0,
      'Marketing / Content Strategist': 0,
      'Business Analyst': 0,
      'Cybersecurity Analyst': 0,
      'DevOps / SRE': 0,
    };

    void add(List<String> roles, [int pts = 2]) {
      for (final r in roles) {
        s[r] = (s[r] ?? 0) + pts;
      }
    }

    // Grade / status influence
    switch (grade) {
      case GradeStatus.undergradCS:
        add(['Software Engineer', 'Data Scientist', 'Cybersecurity Analyst', 'DevOps / SRE']);
        break;
      case GradeStatus.undergradDesign:
        add(['UX Designer', 'Marketing / Content Strategist']);
        break;
      case GradeStatus.undergradEngineering:
        add(['Electrical Engineer', 'DevOps / SRE', 'Research Scientist']);
        break;
      case GradeStatus.graduateResearch:
        add(['Research Scientist', 'Data Scientist']);
        break;
      case GradeStatus.bootcamp:
        add(['Software Engineer', 'UX Designer', 'Cybersecurity Analyst']);
        break;
      case GradeStatus.selfTaught:
        add(['Software Engineer', 'DevOps / SRE', 'Marketing / Content Strategist']);
        break;
      case GradeStatus.businessSchool:
        add(['Product Manager', 'Business Analyst', 'Marketing / Content Strategist']);
        break;
      case GradeStatus.highSchool:
      case null:
        // neutral
        break;
    }

    // Interests
    if (interests['Coding / building software'] == true) {
      add(['Software Engineer', 'Cybersecurity Analyst', 'DevOps / SRE', 'Data Scientist']);
    }
    if (interests['Design / UX / visuals'] == true) {
      add(['UX Designer', 'Product Manager', 'Marketing / Content Strategist']);
    }
    if (interests['Numbers / data'] == true) {
      add(['Data Scientist', 'Business Analyst', 'Product Manager']);
    }
    if (interests['People / teaching'] == true) {
      add(['Teacher / Trainer', 'Product Manager', 'Marketing / Content Strategist']);
    }
    if (interests['Writing / communication'] == true) {
      add(['Marketing / Content Strategist', 'Product Manager', 'Teacher / Trainer', 'Business Analyst']);
    }
    if (interests['Hardware / electronics'] == true) {
      add(['Electrical Engineer', 'DevOps / SRE', 'Cybersecurity Analyst']);
    }
    if (interests['Business / entrepreneurship'] == true) {
      add(['Product Manager', 'Business Analyst', 'Marketing / Content Strategist']);
    }
    if (interests['Science / research'] == true) {
      add(['Research Scientist', 'Data Scientist', 'Electrical Engineer']);
    }

    // Working style
    switch (styleSoloTeam) {
      case 'Solo':
        add(['Software Engineer', 'Data Scientist', 'Research Scientist', 'Cybersecurity Analyst', 'DevOps / SRE']);
        break;
      case 'Team':
        add(['Product Manager', 'UX Designer', 'Marketing / Content Strategist', 'Teacher / Trainer', 'Business Analyst']);
        break;
    }
    switch (styleWorkplace) {
      case 'Remote-friendly':
        add(['Software Engineer', 'Data Scientist', 'DevOps / SRE', 'Cybersecurity Analyst']);
        break;
      case 'On-site / in-person':
        add(['Electrical Engineer', 'Teacher / Trainer', 'UX Designer', 'Product Manager']);
        break;
    }
    switch (styleHandsTheoretical) {
      case 'Hands-on / practical':
        add(['Electrical Engineer', 'DevOps / SRE', 'UX Designer']);
        break;
      case 'Theoretical / analytical':
        add(['Data Scientist', 'Research Scientist', 'Business Analyst']);
        break;
    }
    switch (styleCreativityStructure) {
      case 'Creative / open-ended':
        add(['UX Designer', 'Marketing / Content Strategist', 'Product Manager']);
        break;
      case 'Structured / process-driven':
        add(['Software Engineer', 'Cybersecurity Analyst', 'Business Analyst', 'DevOps / SRE']);
        break;
    }

    // Skills
    if (skills['Math / statistics'] == true) {
      add(['Data Scientist', 'Electrical Engineer', 'Business Analyst']);
    }
    if (skills['Programming'] == true) {
      add(['Software Engineer', 'DevOps / SRE', 'Cybersecurity Analyst', 'Data Scientist']);
    }
    if (skills['Art / visual design'] == true) {
      add(['UX Designer', 'Marketing / Content Strategist']);
    }
    if (skills['Communication / storytelling'] == true) {
      add(['Product Manager', 'Teacher / Trainer', 'Marketing / Content Strategist', 'Business Analyst']);
    }
    if (skills['Biology / chemistry'] == true) {
      add(['Research Scientist', 'Electrical Engineer']);
    }
    if (skills['Systems / IT / admin'] == true) {
      add(['DevOps / SRE', 'Cybersecurity Analyst']);
    }

    final sorted = s.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    scores = s;
    return sorted.take(3).toList();
  }

  String _makeSummary() {
    final pickedInterests = interests.entries.where((e) => e.value).map((e) => e.key).toList();
    final pickedSkills = skills.entries.where((e) => e.value).map((e) => e.key).toList();
    final parts = <String>[];
    if (grade != null) parts.add('Status: ${_gradeLabel(grade!)}');
    if (institutionCtrl.text.trim().isNotEmpty) parts.add('Institution: ${institutionCtrl.text.trim()}');
    if (pickedInterests.isNotEmpty) parts.add('Interests: ${pickedInterests.join(', ')}');
    if (styleSoloTeam != null) parts.add('Prefers: $styleSoloTeam work');
    if (styleWorkplace != null) parts.add('Workplace: $styleWorkplace');
    if (styleHandsTheoretical != null) parts.add('Approach: $styleHandsTheoretical');
    if (styleCreativityStructure != null) parts.add('Style: $styleCreativityStructure');
    if (pickedSkills.isNotEmpty) parts.add('Skills: ${pickedSkills.join(', ')}');
    return parts.join(' • ');
  }

  bool _validateStep() {
    switch (step) {
      case 0:
        return grade != null; // at least grade
      case 1:
        return interests.values.any((v) => v);
      case 2:
        return styleSoloTeam != null &&
            styleWorkplace != null &&
            styleHandsTheoretical != null &&
            styleCreativityStructure != null;
      case 3:
        return skills.values.any((v) => v);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildStep0(context),
      _buildStep1(context),
      _buildStep2(context),
      _buildStep3(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Predictor'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (step + 1) / 4,
              minHeight: 6,
            ),
            Expanded(child: pages[step]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (step > 0)
                    OutlinedButton.icon(
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _validateStep() ? next : null,
                    icon: Icon(step < 3 ? Icons.arrow_forward : Icons.check),
                    label: Text(step < 3 ? 'Next' : 'See Results'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child, String? subtitle, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) Icon(icon, color: Theme.of(context).colorScheme.primary),
                  if (icon != null) const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep0(BuildContext context) {
    return _buildCard(
      title: 'Tell us about your studies',
      subtitle: 'What grade or education status are you in? Where are you studying?',
      icon: Icons.school,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<GradeStatus>(
            value: grade,
            decoration: const InputDecoration(
              labelText: 'Grade / status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: GradeStatus.highSchool, child: Text('High school')),
              DropdownMenuItem(value: GradeStatus.undergradCS, child: Text('Undergraduate – CS / IT')),
              DropdownMenuItem(value: GradeStatus.undergradDesign, child: Text('Undergraduate – Design / Arts')),
              DropdownMenuItem(value: GradeStatus.undergradEngineering, child: Text('Undergraduate – Engineering (non-CS)')),
              DropdownMenuItem(value: GradeStatus.businessSchool, child: Text('Undergraduate/Graduate – Business / MBA')),
              DropdownMenuItem(value: GradeStatus.graduateResearch, child: Text('Graduate – Research / MSc / PhD')),
              DropdownMenuItem(value: GradeStatus.bootcamp, child: Text('Bootcamp')),
              DropdownMenuItem(value: GradeStatus.selfTaught, child: Text('Self-taught')),
            ],
            onChanged: (v) => setState(() => grade = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: institutionCtrl,
            decoration: const InputDecoration(
              labelText: 'School / institution (optional)',
              hintText: 'e.g., University name or city',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    return _buildCard(
      title: 'Your interests',
      subtitle: 'Pick a few areas you genuinely enjoy.',
      icon: Icons.favorite_outline,
      child: Column(
        children: [
          for (final entry in interests.entries)
            CheckboxListTile(
              value: entry.value,
              title: Text(entry.key),
              onChanged: (v) => setState(() => interests[entry.key] = v ?? false),
            ),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    return _buildCard(
      title: 'Working style',
      subtitle: 'Choose the options that describe you best.',
      icon: Icons.work_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Do you prefer working mostly solo or in a team?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Solo'),
                selected: styleSoloTeam == 'Solo',
                onSelected: (_) => setState(() => styleSoloTeam = 'Solo'),
              ),
              ChoiceChip(
                label: const Text('Team'),
                selected: styleSoloTeam == 'Team',
                onSelected: (_) => setState(() => styleSoloTeam = 'Team'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('What kind of workplace?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Remote-friendly'),
                selected: styleWorkplace == 'Remote-friendly',
                onSelected: (_) => setState(() => styleWorkplace = 'Remote-friendly'),
              ),
              ChoiceChip(
                label: const Text('On-site / in-person'),
                selected: styleWorkplace == 'On-site / in-person',
                onSelected: (_) => setState(() => styleWorkplace = 'On-site / in-person'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('What describes your approach better?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Hands-on / practical'),
                selected: styleHandsTheoretical == 'Hands-on / practical',
                onSelected: (_) => setState(() => styleHandsTheoretical = 'Hands-on / practical'),
              ),
              ChoiceChip(
                label: const Text('Theoretical / analytical'),
                selected: styleHandsTheoretical == 'Theoretical / analytical',
                onSelected: (_) => setState(() => styleHandsTheoretical = 'Theoretical / analytical'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Do you lean more creative or structured?'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Creative / open-ended'),
                selected: styleCreativityStructure == 'Creative / open-ended',
                onSelected: (_) => setState(() => styleCreativityStructure = 'Creative / open-ended'),
              ),
              ChoiceChip(
                label: const Text('Structured / process-driven'),
                selected: styleCreativityStructure == 'Structured / process-driven',
                onSelected: (_) => setState(() => styleCreativityStructure = 'Structured / process-driven'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context) {
    return _buildCard(
      title: 'Your skills',
      subtitle: 'Check the skills you enjoy using.',
      icon: Icons.bolt_outlined,
      child: Column(
        children: [
          for (final entry in skills.entries)
            CheckboxListTile(
              value: entry.value,
              title: Text(entry.key),
              onChanged: (v) => setState(() => skills[entry.key] = v ?? false),
            ),
        ],
      ),
    );
  }

  String _gradeLabel(GradeStatus g) {
    switch (g) {
      case GradeStatus.highSchool:
        return 'High school';
      case GradeStatus.undergradCS:
        return 'Undergraduate – CS / IT';
      case GradeStatus.undergradDesign:
        return 'Undergraduate – Design / Arts';
      case GradeStatus.undergradEngineering:
        return 'Undergraduate – Engineering (non-CS)';
      case GradeStatus.businessSchool:
        return 'Business / MBA';
      case GradeStatus.graduateResearch:
        return 'Graduate – Research';
      case GradeStatus.bootcamp:
        return 'Bootcamp';
      case GradeStatus.selfTaught:
        return 'Self-taught';
    }
  }
}

class ResultsPage extends StatelessWidget {
  final String institution;
  final GradeStatus? grade;
  final List<MapEntry<String, int>> top;
  final String selectionsSummary;

  const ResultsPage({
    super.key,
    required this.institution,
    required this.grade,
    required this.top,
    required this.selectionsSummary,
  });

  @override
  Widget build(BuildContext context) {
    final best = top.isNotEmpty ? top.first : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Predicted Job'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (best != null)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Match', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        best.key,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(_roleDescription(best.key), style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why this match', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(selectionsSummary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Other good fits', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final e in top.skip(1))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.star_border, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key)),
                            Text('${e.value}')
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.edit),
                  label: const Text('Adjust answers'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _startOver(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Start over'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _startOver(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SurveyPage()),
    );
  }

  String _roleDescription(String role) {
    switch (role) {
      case 'Software Engineer':
        return 'Designs and builds software systems and applications.';
      case 'Data Scientist':
        return 'Analyzes data to extract insights and build predictive models.';
      case 'UX Designer':
        return 'Creates intuitive, accessible user experiences and interfaces.';
      case 'Product Manager':
        return 'Defines product vision, prioritizes features, and aligns teams.';
      case 'Teacher / Trainer':
        return 'Educates others and develops learning experiences and content.';
      case 'Electrical Engineer':
        return 'Designs and tests electrical systems, hardware, and devices.';
      case 'Research Scientist':
        return 'Conducts experiments and advances knowledge in a specific field.';
      case 'Marketing / Content Strategist':
        return 'Crafts messaging, content, and campaigns to reach audiences.';
      case 'Business Analyst':
        return 'Translates business needs into solutions using data and process.';
      case 'Cybersecurity Analyst':
        return 'Protects systems and data, monitors threats and vulnerabilities.';
      case 'DevOps / SRE':
        return 'Builds reliable infrastructure, automation, and deployment pipelines.';
      default:
        return '';
    }
  }
}
