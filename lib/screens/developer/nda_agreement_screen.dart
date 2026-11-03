import 'package:flutter/material.dart';

class NdaAgreementScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const NdaAgreementScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<NdaAgreementScreen> createState() => _NdaAgreementScreenState();
}

class _NdaAgreementScreenState extends State<NdaAgreementScreen> {
  bool _isAgreed = false;
  bool _hasReadAgreement = false;

  static const String ndaVersion = '1.0';

  static const Color primaryColor = Color(0xFF2563EB);
  static const Color darkColor = Color(0xFF0F172A);
  static const Color mutedColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkColor),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Non-Disclosure Agreement',
          style: TextStyle(
            color: darkColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Expanded(child: _buildAgreementCard()),
                  const SizedBox(height: 16),
                  _buildAgreementCheckbox(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confidentiality Agreement',
                  style: TextStyle(
                    color: darkColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Project: ${widget.projectTitle}',
                  style: const TextStyle(color: mutedColor, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  'Agreement Version: $ndaVersion',
                  style: const TextStyle(color: mutedColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AGREEMENT CONTENT
  // ============================================================

  Widget _buildAgreementCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            final metrics = notification.metrics;

            if (metrics.pixels >= metrics.maxScrollExtent - 20) {
              if (!_hasReadAgreement) {
                setState(() {
                  _hasReadAgreement = true;
                });
              }
            }
          }

          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'NON-DISCLOSURE AGREEMENT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkColor,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              _section(
                '1. Purpose',
                'This Non-Disclosure Agreement (NDA) establishes '
                    'the confidentiality obligations between the '
                    'Client and Developer regarding information '
                    'shared during the project collaboration '
                    'through SkillBridge.',
              ),

              _section(
                '2. Confidential Information',
                'Confidential Information includes project '
                    'requirements, business plans, technical '
                    'documents, source code, designs, credentials, '
                    'customer information, financial details, '
                    'proprietary processes, and any other '
                    'information identified as confidential.',
              ),

              _section(
                '3. Developer Obligations',
                'The Developer agrees to:\n\n'
                    '• Keep all confidential information private.\n'
                    '• Use confidential information only for '
                    'the assigned project.\n'
                    '• Not disclose information to unauthorized '
                    'third parties.\n'
                    '• Not copy, distribute, or misuse project '
                    'materials without permission.\n'
                    '• Take reasonable measures to protect '
                    'confidential information.',
              ),

              _section(
                '4. Restrictions on Disclosure',
                'The Developer shall not publish, share, sell, '
                    'transfer, or disclose confidential project '
                    'information without prior written permission '
                    'from the Client, except where disclosure is '
                    'required by applicable law.',
              ),

              _section(
                '5. Intellectual Property',
                'Acceptance of this NDA does not independently '
                    'transfer intellectual property ownership. '
                    'Ownership, licensing, and rights relating '
                    'to project deliverables shall be governed '
                    'by the applicable project agreement or '
                    'separate written agreement between the '
                    'Client and Developer.',
              ),

              _section(
                '6. Duration of Confidentiality',
                'The confidentiality obligations shall continue '
                    'during the project and for the period '
                    'specified in the applicable project '
                    'agreement or as required by applicable law.',
              ),

              _section(
                '7. Return or Deletion of Information',
                'Upon project completion or termination, the '
                    'Developer shall return or securely delete '
                    'confidential materials when reasonably '
                    'requested by the Client, subject to '
                    'applicable legal requirements.',
              ),

              _section(
                '8. Breach',
                'Unauthorized disclosure or misuse of confidential '
                    'information may result in project termination '
                    'and other remedies available under the '
                    'applicable agreement and law.',
              ),

              _section(
                '9. Acceptance',
                'By accepting this agreement, the Developer '
                    'acknowledges that they have read and '
                    'understood these confidentiality obligations '
                    'and agree to comply with them in connection '
                    'with the project.',
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB45309)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Please read the complete agreement carefully '
                        'before accepting it. This is a general '
                        'template and should be reviewed by a '
                        'qualified legal professional before '
                        'being used as a binding agreement.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AGREEMENT SECTION
  // ============================================================

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: darkColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHECKBOX
  // ============================================================

  Widget _buildAgreementCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isAgreed ? primaryColor : const Color(0xFFE2E8F0),
        ),
      ),
      child: CheckboxListTile(
        value: _isAgreed,
        onChanged: _hasReadAgreement
            ? (value) {
                setState(() {
                  _isAgreed = value ?? false;
                });
              }
            : null,
        activeColor: primaryColor,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I have read and agree to the Non-Disclosure Agreement.',
          style: TextStyle(
            color: darkColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _hasReadAgreement ? 'You can now accept the agreement.' : 'Scroll to the bottom of the agreement to enable this checkbox.',
          style: const TextStyle(color: mutedColor, fontSize: 12),
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Text(
              'Decline',
              style: TextStyle(color: darkColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: _isAgreed ? _acceptAgreement : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: primaryColor.withValues(alpha: 0.35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Accept & Continue',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACCEPT AGREEMENT
  // ============================================================

  void _acceptAgreement() {
    if (!_isAgreed) return;

    Navigator.pop(context, true);
  }
}
