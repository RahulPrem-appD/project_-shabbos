import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  final String locale;

  const AboutScreen({super.key, required this.locale});

  bool get isHebrew => locale == 'he';

  // Dedication text - easily editable
  static const String dedicationEn = '''This app is dedicated to the loving and blessed memory of my father
Shmuel Hirsh ben Mordechai Menachem Mendel ז״ל,
my mother Betty bas Yechiel ע״ה,
and my wife's father Levi ben Ephraim ז״ל.

May their neshamos continue to rise higher and higher in Gan Eden,
and may they be meilitzei tov for their entire family
and for all of Klal Yisrael.''';

  static const String dedicationHe = '''לעילוי נשמת אבי
שמואל הירש בן מרדכי מנחם מענדל ז״ל,
אמי בעטי בת יחיאל ע״ה,
ואבי חמותי לוי בן אפרים ז״ל.

תהא נשמתם צרורה בצרור החיים,
ויהיו מליצי יושר לכל משפחתם
ולכל כלל ישראל.''';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isHebrew ? 'אודות' : 'About',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('בס״ד', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    '🕯️🕯️',
                    style: TextStyle(fontSize: 36),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                isHebrew ? 'שבת!!' : 'Shabbos!!',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                isHebrew ? 'הדלקת נרות שבת ויום טוב' : 'Shabbat & Yom Tov Candle Lighting',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // About section
              _buildSection(
                icon: Icons.info_outline,
                title: isHebrew ? 'אודות האפליקציה' : 'About',
                content: isHebrew
                    ? 'שבת!! היא אפליקציה פשוטה לזמני הדלקת נרות שבת ויום טוב.\n\nשני סימני הקריאה (!!) מסמלים את שני נרות השבת.\n\nהאפליקציה משתמשת ב-HebCal לחישוב הזמנים. אין צורך בחשבון משתמש, ואין איסוף מידע.'
                    : 'Shabbos!! is a simple app for Shabbat and Yom Tov candle lighting times.\n\nThe two exclamation points (!!) symbolize the two Shabbat candles.\n\nThe app uses HebCal for time calculations. No account needed, no data collection.',
              ),
              
              const SizedBox(height: 24),
              
              // Dedication section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8B923).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_fire_department, color: const Color(0xFFE8B923), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isHebrew ? 'הקדשה' : 'Dedication',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.local_fire_department, color: const Color(0xFFE8B923), size: 20),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isHebrew ? dedicationHe : dedicationEn,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              Text(
                'שבת שלום!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 4),
              
              Text(
                'Good Shabbos!',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
