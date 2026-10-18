// Build theme/Vellum.terminal, the Terminal profile, from the colours below.
//
// Run with: osascript -l JavaScript theme/build-profile.js
// Paper Mono must be installed first, because Terminal stores the font itself.
// The colours come from the Vellum colour scheme. All are sRGB.

ObjC.import('AppKit');

var COLOURS = {
  BackgroundColor: '#F3EBD8',
  TextColor: '#302B24',
  TextBoldColor: '#191611',
  SelectionColor: '#D8C7A5',
  CursorColor: '#75583A',
  ANSIBlackColor: '#302B24',
  ANSIRedColor: '#944238',
  ANSIGreenColor: '#426448',
  ANSIYellowColor: '#80601F',
  ANSIBlueColor: '#365C80',
  ANSIMagentaColor: '#775071',
  ANSICyanColor: '#34676A',
  ANSIWhiteColor: '#D8CFBD',
  ANSIBrightBlackColor: '#706759',
  ANSIBrightRedColor: '#A04438',
  ANSIBrightGreenColor: '#486C46',
  ANSIBrightYellowColor: '#86631D',
  ANSIBrightBlueColor: '#3C6590',
  ANSIBrightMagentaColor: '#855379',
  ANSIBrightCyanColor: '#397175',
  ANSIBrightWhiteColor: '#F9F3E6'
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
