class MoodData {
  final String emoji;
  final String title;
  final String subtitle;
  final String question;

  const MoodData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.question,
  });
}

// Define mood data for each index
const List<MoodData> moodDataList = [
  MoodData(
    emoji: '😔',
    title: 'You feel heavy today.',
    subtitle: 'Some days weigh on the heart more than others.',
    question: 'Would you like to sit with the Guru and share what you’re carrying?',
  ),
  MoodData(
    emoji: '😕',
    title: 'Something feels unsettled within you.',
    subtitle: 'When the mind is restless, clarity is often just beneath the surface.',
    question: 'Would you like to explore this with the Guru?',
  ),
  MoodData(
    emoji: '😐',
    title: 'You feel steady and balanced.',
    subtitle: 'This is a good space to reflect and deepen your awareness.',
    question: 'Would you like to spend a few moments with the Guru?',
  ),
  MoodData(
    emoji: '🙂',
    title: 'There is a lightness within you today.',
    subtitle: 'This is a beautiful time to nurture it further.',
    question: 'Would you like to continue this with the Guru?',
  ),
  MoodData(
    emoji: '😄',
    title: 'You feel joyful today.',
    subtitle: 'Joy shared becomes devotion.',
    question: 'Would you like to offer this moment with the Guru?',
  ),
];