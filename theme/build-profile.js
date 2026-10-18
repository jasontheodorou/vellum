// Build theme/Vellum.terminal, the Terminal profile, from the colours below.
//
// Run with: osascript -l JavaScript theme/build-profile.js theme
// Paper Mono must be installed first, because Terminal stores the font itself.
// The colours come from the Vellum colour scheme. All are sRGB.

ObjC.import('AppKit');

// Man Page brightened: soft yellow paper, charcoal ink and crisp accents. Only
// these colours are set; the other ANSI colours keep Terminal's defaults, as
// Man Page does.
var COLOURS = {
  BackgroundColor: '#FFF095',
  TextColor: '#282923',
  TextBoldColor: '#171813',
  CursorColor: '#B53668',
  SelectionColor: '#D5E5F5',
  ANSIRedColor: '#B63E32',
  ANSIGreenColor: '#347348',
  ANSIYellowColor: '#876000',
  ANSIBlueColor: '#3455C5',
  ANSIMagentaColor: '#B53668'
};

var FONT = 'PaperMono-Regular';
var FONT_SIZE = 18;

function archive(obj) {
  var data = $.NSKeyedArchiver.archivedDataWithRootObjectRequiringSecureCodingError(obj, false, null);
  if (data.isNil()) throw new Error('could not archive ' + obj);
  return data;
}

function colour(hex) {
  var n = parseInt(hex.slice(1), 16);
  return $.NSColor.colorWithSRGBRedGreenBlueAlpha(
    ((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1);
}

function run(argv) {
  var here = $.NSString.stringWithString(argv[0] || 'theme').stringByStandardizingPath.js;
  var font = $.NSFont.fontWithNameSize(FONT, FONT_SIZE);
  if (font.isNil()) throw new Error(FONT + ' is not installed. Install theme/fonts/ first.');

  var p = $.NSMutableDictionary.dictionary;
  Object.keys(COLOURS).forEach(function (key) {
    p.setObjectForKey(archive(colour(COLOURS[key])), key);
  });
  p.setObjectForKey(archive(font), 'Font');
  p.setObjectForKey($(true), 'FontAntialias');
  p.setObjectForKey($(1.0), 'FontWidthSpacing');
  p.setObjectForKey($(1.0), 'FontHeightSpacing');
  p.setObjectForKey($(100), 'columnCount');
  p.setObjectForKey($(30), 'rowCount');
  p.setObjectForKey($('Vellum'), 'name');
  p.setObjectForKey($('Window Settings'), 'type');
  p.setObjectForKey($(2.07), 'ProfileCurrentVersion');

  var out = here + '/Vellum.terminal';
  if (!p.writeToFileAtomically(out, true)) throw new Error('could not write ' + out);
  return 'Wrote ' + out;
}
