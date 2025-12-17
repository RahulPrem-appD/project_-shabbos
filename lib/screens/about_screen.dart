import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  final String locale;
  final bool showAppBar;

  const AboutScreen({super.key, required this.locale, this.showAppBar = true});

  bool get isHebrew => locale == 'he';

  // About the App text
  static const String aboutEn =
      '''Shabbos!! was created out of a love for the special atmosphere that surrounds the moments before Shabbat and Yom Tov.

In Jerusalem and in many cities throughout Israel, a siren is sounded about 20 minutes before candle lighting, and again at candle lighting time. In some places, gentle music is played during those final minutes, creating a unique feeling of calm, anticipation, and holiness as Shabbat approaches.

While visiting Beit Shemesh, I experienced this once again and was deeply moved by it. I have always loved that atmosphere and wished that it existed in my own city — but it does not.

That experience sparked an idea.

I began experimenting by setting my own reminders and alarms to recreate that feeling, and I immediately felt how meaningful it was. The transition into Shabbat became calmer, more focused, and more uplifting.

From there, Shabbos!! was born — an app designed to give everyone that experience:

• Those living outside of Israel who want to feel connected to the rhythm of Shabbat in Eretz Yisrael

• And those living in Israel whose cities do not offer this kind of reminder

With this app, the feeling of welcoming Shabbat can be right at your fingertips — wherever you are.''';

  static const String aboutHe =
      '''!!שבת נוצרה מתוך אהבה לאווירה המיוחדת של הרגעים שלפני כניסת שבת ויום טוב.

בירושלים ובערים רבות ברחבי הארץ, מושמעת צפירה כ־20 דקות לפני הדלקת נרות, ושוב בזמן הדלקת הנרות. במקומות מסוימים אף מתנגנת מוזיקה שקטה באותן דקות אחרונות, ויוצרת תחושה מיוחדת של רוגע, ציפייה וקדושה לקראת כניסת השבת.

בעת שהותי בבית שמש חוויתי זאת שוב, והדבר נגע בי מאוד. תמיד אהבתי את האווירה הזו, ותמיד הצטערתי שבמקום מגוריי אין דבר דומה.

מאותה חוויה נולד הרעיון.

התחלתי להתנסות בעצמי, בעזרת תזכורות והתראות פשוטות, כדי לנסות לשחזר את אותה תחושה — ומיד הרגשתי עד כמה זה משמעותי. הכניסה לשבת הפכה רגועה יותר, ממוקדת יותר ומרוממת יותר.

כך נולדה !!שבת — אפליקציה שנועדה לאפשר לכל אחד לחוות את התחושה הזו:

• לאלו המתגוררים מחוץ לארץ ורוצים להתחבר לקצב ולרוח השבת בארץ ישראל

• ולאלו המתגוררים בארץ, אך בעירם אין תזכורת או אווירה כזו

באמצעות האפליקציה, תחושת קבלת השבת יכולה להיות זמינה ונגישה — בכל מקום.''';

  // Dedication text
  static const String dedicationEn =
      '''This app is dedicated to the loving and blessed memory of my father
Shmuel Hirsh ben Mordechai Menachem Mendel ז״ל,
my mother Betty bas Yechiel ע״ה,
and my wife's father Levi ben Ephraim ז״ל.

May their neshamos continue to rise higher and higher in Gan Eden,
and may they be meilitzei tov for their entire family
and for all of Klal Yisrael.''';

  static const String dedicationHe =
      '''אפליקציה זו מוקדשת לזכרם האוהב והמבורך של
אבי, שמואל הירש בן מרדכי מנחם מנדל ז״ל,
אמי, בטי בת יחיאל ע״ה,
וחמי, לוי בן אפרים ז״ל.

יהי רצון שנשמותיהם ימשיכו לעלות מעלה מעלה בגן עדן,
ויהיו מליצי יושר על משפחתם
ועל כל כלל ישראל.''';

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
                  isHebrew ? '!!שבת' : 'Shabbos!!',
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            size: 20,
                            color: Color(0xFF1A1A1A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHebrew ? 'אודות האפליקציה' : 'About the App',
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
                        isHebrew ? aboutHe : aboutEn,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Dedication section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE8B923).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFE8B923),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHebrew ? 'הקדשה' : 'Dedication',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFE8B923),
                            size: 20,
                          ),
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
                  '!שבת שלום',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Good Shabbos!',
                  style: TextStyle(fontSize: 15, color: Colors.grey[400]),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
