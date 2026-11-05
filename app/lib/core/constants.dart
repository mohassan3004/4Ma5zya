class AppInfo {
  static const name = '4Ma5zya';
  static const version = '1.0.0';
}

/// Audio formats accepted for voice samples (validated again on the server).
const supportedAudioExtensions = <String>[
  'mp3', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'flac', 'webm', 'mp4',
];

/// Minimum total duration of samples required to create a voice (matches the backend default).
const minTotalSampleSeconds = 30;

/// Recommended total duration for good similarity.
const recommendedSampleSeconds = 90;

/// Maximum size of a single sample file (matches the backend default of 11 MB).
const maxSampleBytes = 11 * 1024 * 1024;

const playbackSpeeds = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Text the user is invited to read aloud while recording a sample.
const recordingScripts = <String>[
  'بسم الله، أبدأ هذا التسجيل بصوتي الطبيعي وبنبرة هادئة وواضحة. '
      'القراءة عادة جميلة تفتح للإنسان أبواب المعرفة، وتمنحه فرصة للتأمل والتفكير.',
  'في صباح يوم مشمس، خرج الطالب إلى المكتبة العامة يبحث عن كتاب في التاريخ. '
      'وجد رفوفًا طويلة مليئة بالمجلدات، فاختار كتابًا عن الحضارة العربية في الأندلس.',
  'تنص المادة الأولى على أن تسري أحكام هذا القانون على جميع العقود المبرمة بعد تاريخ نفاذه. '
      'وتلتزم الأطراف بتنفيذ التزاماتها بحسن نية، وفقًا لما اشتمل عليه العقد.',
  'هل تساءلت يومًا كيف تعمل التقنية من حولنا؟ إن الحاسوب الذي بين يديك يعالج ملايين العمليات في الثانية الواحدة! '
      'ومع ذلك، يبقى العقل البشري أكثر إبداعًا ومرونة.',
  'الأرقام مهمة أيضًا: في عام ألفين وخمسة وعشرين، بلغ عدد المشاركين ثلاثمئة وخمسين مشاركًا، '
      'وارتفعت النسبة بمقدار خمسة عشر بالمئة مقارنة بالعام السابق.',
];

const defaultPreviewText =
    'مرحبًا، هذا مثال على صوتي المستنسخ. سأقرأ لك مستنداتك العربية بوضوح وبنبرة طبيعية.';
