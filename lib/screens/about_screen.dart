import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  final String locale;
  final bool showAppBar;

  const AboutScreen({super.key, required this.locale, this.showAppBar = true});

  bool get isHebrew => locale == 'he';

  // About the App text
  static const String aboutEn =
      '''Shabbos!! was created out of a love for the special atmosphere that surrounds the moments before Shabbat and Yom Tov.

In Jerusalem and in many cities throughout Israel, a siren is sounded about 20 minutes before candle lighting, and again at candle-lighting time. In some places, gentle music is played during those final minutes, creating a unique feeling of calm, anticipation, and holiness as Shabbat approaches.

While visiting Beit Shemesh, I experienced this once again and was deeply moved by it. I have always loved that atmosphere and wished that it existed in my own city — but it does not.

That experience sparked an idea.

I began experimenting by setting my own reminders and alarms to recreate that feeling, and I immediately felt how meaningful it was. The transition into Shabbat became calmer, more focused, and more uplifting.

From there, Shabbos!! was born — an app designed to give everyone that experience:

• Those living outside of Israel who want to feel connected to the rhythm of Shabbat in Eretz Yisrael

• And those living in Israel whose cities do not offer this kind of reminder

With this app, the feeling of welcoming Shabbat can be right at your fingertips — wherever you are.''';

  static const String aboutHe =
      '''Shabbos!! נוצרה מתוך אהבה לאווירה המיוחדת המלווה את הרגעים שלפני כניסת שבת ויום טוב.

בירושלים ובערים רבות ברחבי ארץ ישראל, נשמעת צפירה כ־20 דקות לפני הדלקת הנרות, ושוב בזמן הדלקת הנרות. במקומות מסוימים מתנגנת מוזיקה שקטה בדקות האחרונות הללו, ויוצרת תחושה מיוחדת של רוגע, ציפייה וקדושה עם התקרבות השבת.

במהלך ביקור בבית שמש חוויתי זאת שוב, והדבר ריגש אותי מאוד. תמיד אהבתי את האווירה הזו, ותמיד ייחלתי שתהיה גם בעיר שבה אני גר — אך לצערי, אין.

החוויה הזו הציתה בי רעיון.

התחלתי לנסות להשתמש בהגדרת תזכורות וצופר כדי לשחזר את התחושה הזו, ומיד הרגשתי עד כמה הדבר משמעותי. המעבר אל השבת הפך להיות רגוע יותר, ממוקד יותר ומרומם יותר.

ומשם נולדה Shabbos!! — אפליקציה שנועדה להעניק את החוויה הזו לכולם:

• לאלו החיים מחוץ לארץ ישראל ורוצים להתחבר לקצב השבת בארץ

• ולאלו החיים בישראל, אך בעירם אין תזכורת מסוג זה

באמצעות האפליקציה הזו, תחושת קבלת השבת יכולה להיות ממש בקצות האצבעות — בכל מקום שבו אתם נמצאים.''';

  // Dedication text
  static const String dedicationEn =
      '''This app is dedicated to the loving and blessed memory of my father,
Shmuel Hirsh ben Mordechai Menachem Mendel ז״ל,
my mother, Betty bas Yechiel ע״ה,
and my wife's father, Levi ben Ephraim ז״ל,
who was very careful about taking in Shabbat on time.

My dear and beloved friends' parents:
Mordechai ben Aaron HaCohen ז״ל
Yenta bat Avraham HaLevy ז״ל

May their neshamos continue to rise higher and higher in Gan Eden,
and may they be meilitzei tov for their entire family
and for all of Klal Yisrael.''';

  static const String dedicationHe =
      '''אפליקציה זו מוקדשת לזכרם האוהב והמבורך של
אבי, שמואל הירש בן מרדכי מנחם מנדל ז״ל,
אמי, בטי בת יחיאל ע״ה,
וחמי, לוי בן אפרים ז״ל, שהיה מדקדק מאוד בקבלת השבת בזמן.

הורי ידידי היקר והאהוב
מרדכי בן אהרן הכהן ז״ל
ינטה בת אברהם הלוי ז״ל

יהי רצון שנשמותיהם ימשיכו לעלות מעלה מעלה בגן עדן,
ויהיו מליצי יושר בעד כל משפחתם
ובעבור כל ישראל.''';

  // Credits text (without developer name - added separately as clickable link)
  static const String creditsEn = '''Music & Sound
• Traditional Hebrew liturgical texts (public domain)
• Original AI-generated music (licensed)
• Shofar recordings – Used with permission Rabbi Shalom Gold
• "Shabbat Shalom" – Used with permission of Rabbi Yom Tov Glaser

App Development''';

  static const String creditsHe = '''מוזיקה וקול
• טקסטים ליטורגיים עבריים מסורתיים (נחלת הכלל)
• מוזיקה מקורית שנוצרה באמצעות בינה מלאכותית (ברישיון)
• הקלטות שופר – בשימוש באישור הרב שלום גולד
• ״שבת שלום״ – בשימוש באישור הרב יום טוב גלזר

פיתוח האפליקציה''';

  static const String _developerUrl = 'https://fiverr.com/sanjay_prem';

  // Special Thanks text
  static const String thanksEn =
      '''With heartfelt gratitude to my beloved wife, Bat-Sheva, whose love, encouragement, patience, and constant support were a true source of strength and inspiration throughout this entire journey. This project would not exist without her.

And above all, thank You, Hashem, for the guidance, strength, and countless blessings that made this possible.''';

  static const String thanksHe =
      '''בתודה עמוקה ומלאת אהבה לאשתי היקרה, בת־שבע, שעל עידוד, השראה, סבלנות ותמיכה בלתי־פוסקת לאורך כל הדרך — בלעדיה זה לא היה קורה.

ומעל הכול, תודה גדולה להשם יתברך, על ההכוונה, הכוחות והשפע שהביאו את הדבר לידי מימוש.''';

  // Disclaimer text
  static const String disclaimerEn =
      '''This app uses candle-lighting times provided by HebCal. While these times are generally very accurate, they may vary slightly by location and custom, and in some cases may be off by a minute or two.

This app is intended as a helpful reminder and enhancement of the Shabbat and Yom Tov experience, not as a definitive halachic ruling.

Users are encouraged to always double-check candle-lighting times with reliable local sources and follow their community's accepted customs, or consult a Rav for Halacha L'ma'aseh.''';

  static const String disclaimerHe =
      '''האפליקציה משתמשת בזמני הדלקת נרות המסופקים על ידי HebCal. למרות שזמנים אלו מדויקים בדרך כלל, ייתכנו הבדלים קלים בהתאם למיקום ולמנהג, ובמקרים מסוימים סטייה של דקה או שתיים.

האפליקציה נועדה לשמש כתזכורת וכהעצמה לחוויית שבת ויום טוב, ואינה מהווה פסיקה הלכתית מחייבת.

המשתמשים מתבקשים תמיד לבדוק את זמני הדלקת הנרות מול מקורות מקומיים מוסמכים, לנהוג על פי מנהגי קהילתם, או להתייעץ עם רב להלכה למעשה.''';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: showAppBar
            ? AppBar(
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
                      child: Text(
                        'בס״ד',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!showAppBar) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isHebrew ? 'אודות' : 'About',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'בס״ד',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ] else
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
                    child: Text('🕯️🕯️', style: TextStyle(fontSize: 36)),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  isHebrew ? 'שבת!!' : 'Shabbos!!',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  isHebrew
                      ? 'התראת הדלקת נרות לשבת וליום טוב'
                      : 'Candle Lighting Alert for Shabbat and Yom Tov',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF1A1A1A),
                  title: isHebrew ? 'אודות האפליקציה' : 'About the App',
                  content: isHebrew ? aboutHe : aboutEn,
                  backgroundColor: const Color(0xFFF8F8F8),
                ),

                const SizedBox(height: 24),

                // Dedication section
                _buildSection(
                  icon: Icons.local_fire_department,
                  iconColor: const Color(0xFFE8B923),
                  title: isHebrew ? 'הקדשה' : 'Dedication',
                  content: isHebrew ? dedicationHe : dedicationEn,
                  backgroundColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFE8B923).withValues(alpha: 0.3),
                  centered: true,
                ),

                const SizedBox(height: 24),

                // Credits section
                _buildCreditsSection(isHebrew),

                const SizedBox(height: 24),

                // Special Thanks section
                _buildSection(
                  icon: Icons.favorite,
                  iconColor: const Color(0xFFE57373),
                  title: isHebrew ? 'תודות מיוחדות' : 'Special Thanks',
                  content: isHebrew ? thanksHe : thanksEn,
                  backgroundColor: const Color(0xFFFCE4EC),
                  borderColor: const Color(0xFFE57373).withValues(alpha: 0.3),
                ),

                const SizedBox(height: 24),

                // Disclaimer section
                _buildSection(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFFF9800),
                  title: isHebrew ? 'כתב ויתור' : 'Disclaimer',
                  content: isHebrew ? disclaimerHe : disclaimerEn,
                  backgroundColor: const Color(0xFFFFF8E1),
                  borderColor: const Color(0xFFFF9800).withValues(alpha: 0.3),
                ),

                const SizedBox(height: 40),

                // Closing greeting
                Text(
                  isHebrew
                      ? 'גוט שַׁבֶּסססס!!'
                      : 'Gooood Shaaaaaaabbbooossss!!',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8B923),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  isHebrew ? 'אברהם ונשמח' : 'Avraham Venismach',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color backgroundColor,
    Color? borderColor,
    bool centered = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (centered) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 20, color: iconColor),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsSection(bool isHebrew) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, size: 20, color: Color(0xFF5C6BC0)),
              const SizedBox(width: 8),
              Text(
                isHebrew ? 'קרדיטים' : 'Credits',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isHebrew ? creditsHe : creditsEn,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.7,
            ),
          ),
          const SizedBox(height: 4),
          // Developer link
          GestureDetector(
            onTap: _launchDeveloperUrl,
            child: Row(
              children: [
                Text(
                  isHebrew ? '• פיתוח האפליקציה: ' : '• App developed by ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.7,
                  ),
                ),
                Text(
                  'Sanjay Prem',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5C6BC0),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF5C6BC0),
                    height: 1.7,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Color(0xFF5C6BC0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDeveloperUrl() async {
    final uri = Uri.parse(_developerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
