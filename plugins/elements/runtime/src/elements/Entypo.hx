package elements;

/**
 * Entypo icon font character codes.
 * 
 * This enum provides constant values for all available icons in the Entypo icon font.
 * The values correspond to Unicode code points that map to specific icon glyphs when
 * using the Entypo font face.
 * 
 * Entypo is a suite of 411 carefully crafted premium pictograms by Daniel Bruce.
 * The font includes icons for:
 * - User interface elements (arrows, controls, windows)
 * - Media controls (play, pause, stop, volume)
 * - Communication (mail, chat, phone)
 * - Social media platforms
 * - File and document types
 * - Creative Commons licenses
 * - Common objects and symbols
 * 
 * Usage example:
 * ```haxe
 * var icon = new EntypoIconView();
 * icon.icon = Entypo.HEART;
 * icon.iconColor = Color.RED;
 * ```
 * 
 * The icon codes start at 59392 (0xE800) for regular icons and 62208 (0xF300) for
 * social media brand icons.
 * 
 * @see EntypoIconView for displaying these icons
 */
enum abstract Entypo(Int) from Int to Int {
    /** Musical note icon */
    var NOTE:Int = 59392;
    /** Beamed eighth notes icon */
    var NOTE_BEAMED:Int = 59393;
    /** Music/melody icon */
    var MUSIC:Int = 59394;
    /** Magnifying glass search icon */
    var SEARCH:Int = 59395;
    /** Flashlight/torch icon */
    var FLASHLIGHT:Int = 59396;
    /** Envelope/mail icon */
    var MAIL:Int = 59397;
    /** Empty/outlined heart icon */
    var HEART_EMPTY:Int = 59398;
    /** Filled heart icon */
    var HEART:Int = 59399;
    /** Filled star icon */
    var STAR:Int = 59400;
    /** Empty/outlined star icon */
    var STAR_EMPTY:Int = 59401;
    /** Single user/person icon */
    var USER:Int = 59402;
    /** Multiple users/group icon */
    var USERS:Int = 59403;
    /** Add user icon with plus sign */
    var USER_ADD:Int = 59404;
    /** Video camera icon */
    var VIDEO:Int = 59405;
    /** Picture/image icon */
    var PICTURE:Int = 59406;
    /** Photo camera icon */
    var CAMERA:Int = 59407;
    /** Layout/grid icon */
    var LAYOUT:Int = 59408;
    /** Hamburger menu icon */
    var MENU:Int = 59409;
    /** Checkmark/tick icon */
    var CHECK:Int = 59410;
    /** X/cancel icon */
    var CANCEL:Int = 59411;
    /** Tag/label icon */
    var TAG:Int = 59412;
    /** Eye/visibility icon */
    var EYE:Int = 59413;
    /** Unlocked padlock icon */
    var LOCK_OPEN:Int = 59414;
    /** Locked padlock icon */
    var LOCK:Int = 59415;
    /** Paperclip attachment icon */
    var ATTACH:Int = 59416;
    /** Chain link icon */
    var LINK:Int = 59417;
    /** House/home icon */
    var HOME:Int = 59418;
    /** Back/return arrow icon */
    var BACK:Int = 59419;
    /** Information icon in circle */
    var INFO_CIRCLED:Int = 59420;
    /** Information 'i' icon */
    var INFO:Int = 59421;
    /** Help/question mark in circle */
    var HELP_CIRCLED:Int = 59422;
    /** Help/question mark icon */
    var HELP:Int = 59423;
    /** Minus sign in square */
    var MINUS_SQUARED:Int = 59424;
    /** Minus sign in circle */
    var MINUS_CIRCLED:Int = 59425;
    /** Minus/subtract icon */
    var MINUS:Int = 59426;
    /** Plus sign in square */
    var PLUS_SQUARED:Int = 59427;
    /** Plus sign in circle */
    var PLUS_CIRCLED:Int = 59428;
    /** Plus/add icon */
    var PLUS:Int = 59429;
    /** X/cancel in square */
    var CANCEL_SQUARED:Int = 59430;
    /** X/cancel in circle */
    var CANCEL_CIRCLED:Int = 59431;
    /** Bookmark ribbon icon */
    var BOOKMARK:Int = 59432;
    /** Multiple bookmarks icon */
    var BOOKMARKS:Int = 59433;
    /** Flag/marker icon */
    var FLAG:Int = 59434;
    /** Thumbs up/like icon */
    var THUMBS_UP:Int = 59435;
    /** Thumbs down/dislike icon */
    var THUMBS_DOWN:Int = 59436;
    /** Download arrow icon */
    var DOWNLOAD:Int = 59437;
    /** Upload arrow icon */
    var UPLOAD:Int = 59438;
    /** Reply arrow icon */
    var REPLY:Int = 59439;
    /** Upload to cloud icon */
    var UPLOAD_CLOUD:Int = 59440;
    /** Reply all arrows icon */
    var REPLY_ALL:Int = 59441;
    /** Forward arrow icon */
    var FORWARD:Int = 59442;
    /** Quotation marks icon */
    var QUOTE:Int = 59443;
    /** Code brackets icon */
    var CODE:Int = 59444;
    /** Export/share arrow icon */
    var EXPORT:Int = 59445;
    /** Pencil/edit icon */
    var PENCIL:Int = 59446;
    /** Feather/write icon */
    var FEATHER:Int = 59447;
    /** Printer icon */
    var PRINT:Int = 59448;
    /** Retweet/recycle arrows icon */
    var RETWEET:Int = 59449;
    /** Keyboard icon */
    var KEYBOARD:Int = 59450;
    /** Comment bubble icon */
    var COMMENT:Int = 59451;
    /** Closed book icon */
    var BOOK:Int = 59452;
    /** Open book icon */
    var BOOK_OPEN:Int = 59453;
    /** Newspaper/news icon */
    var NEWSPAPER:Int = 59454;
    /** Inverted text document icon */
    var DOC_TEXT_INV:Int = 59455;
    /** Text document icon */
    var DOC_TEXT:Int = 59456;
    /** Landscape document icon */
    var DOC_LANDSCAPE:Int = 59457;
    /** Multiple documents icon */
    var DOCS:Int = 59458;
    /** Single document icon */
    var DOC:Int = 59459;
    /** Trash/delete icon */
    var TRASH:Int = 59460;
    /** Coffee cup icon */
    var CUP:Int = 59461;
    /** Navigation compass icon */
    var COMPASS:Int = 59462;
    /** Direction/waypoint icon */
    var DIRECTION:Int = 59463;
    /** Map/location icon */
    var MAP:Int = 59464;
    /** Location pin icon */
    var LOCATION:Int = 59465;
    /** Address/building icon */
    var ADDRESS:Int = 59466;
    /** Business card/contact icon */
    var VCARD:Int = 59467;
    /** Alert/warning icon */
    var ALERT:Int = 59468;
    /** Attention/caution icon */
    var ATTENTION:Int = 59469;
    /** Bell/notification icon */
    var BELL:Int = 59470;
    /** Chat/messaging icon */
    var CHAT:Int = 59471;
    /** Folder/directory icon */
    var FOLDER:Int = 59472;
    /** Archive/storage icon */
    var ARCHIVE:Int = 59473;
    /** Box/package icon */
    var BOX:Int = 59474;
    /** RSS feed icon */
    var RSS:Int = 59475;
    /** Phone/telephone icon */
    var PHONE:Int = 59476;
    /** Settings/gear icon */
    var COG:Int = 59477;
    /** Share/distribute icon */
    var SHARE:Int = 59478;
    /** Tools/utilities icon */
    var TOOLS:Int = 59479;
    /** Shareable content icon */
    var SHAREABLE:Int = 59480;
    /** Shopping basket icon */
    var BASKET:Int = 59481;
    /** Shopping bag icon */
    var BAG:Int = 59482;
    /** Calendar/date icon */
    var CALENDAR:Int = 59483;
    /** Login/sign in icon */
    var LOGIN:Int = 59484;
    /** Logout/sign out icon */
    var LOGOUT:Int = 59485;
    /** Microphone icon */
    var MIC:Int = 59486;
    /** Mute/silence icon */
    var MUTE:Int = 59487;
    /** Sound/audio icon */
    var SOUND:Int = 59488;
    /** Volume control icon */
    var VOLUME:Int = 59489;
    /** Clock/time icon */
    var CLOCK:Int = 59490;
    /** Hourglass/timer icon */
    var HOURGLASS:Int = 59491;
    /** Small down arrow icon */
    var DOWN_OPEN_MINI:Int = 59492;
    /** Up arrow icon */
    var UP_OPEN:Int = 59493;
    /** Right arrow icon */
    var RIGHT_OPEN:Int = 59494;
    /** Left arrow icon */
    var LEFT_OPEN:Int = 59495;
    /** Down arrow icon */
    var DOWN_OPEN:Int = 59496;
    /** Up arrow in circle */
    var UP_CIRCLED:Int = 59497;
    /** Right arrow in circle */
    var RIGHT_CIRCLED:Int = 59498;
    /** Left arrow in circle */
    var LEFT_CIRCLED:Int = 59499;
    /** Down arrow in circle */
    var DOWN_CIRCLED:Int = 59500;
    /** Multiple arrows/expand icon */
    var ARROW_COMBO:Int = 59501;
    /** Window/dialog icon */
    var WINDOW:Int = 59502;
    /** Publish/release icon */
    var PUBLISH:Int = 59503;
    /** Popup/modal icon */
    var POPUP:Int = 59504;
    /** Resize smaller icon */
    var RESIZE_SMALL:Int = 59505;
    /** Resize fullscreen icon */
    var RESIZE_FULL:Int = 59506;
    /** Block/restrict icon */
    var BLOCK:Int = 59507;
    /** Adjust/tune icon */
    var ADJUST:Int = 59508;
    /** Brightness up icon */
    var LIGHT_UP:Int = 59509;
    /** Brightness down icon */
    var LIGHT_DOWN:Int = 59510;
    /** Lamp/light bulb icon */
    var LAMP:Int = 59511;
    /** Small left arrow icon */
    var LEFT_OPEN_MINI:Int = 59512;
    /** Small right arrow icon */
    var RIGHT_OPEN_MINI:Int = 59513;
    /** Small up arrow icon */
    var UP_OPEN_MINI:Int = 59514;
    /** Large down arrow icon */
    var DOWN_OPEN_BIG:Int = 59515;
    /** Large left arrow icon */
    var LEFT_OPEN_BIG:Int = 59516;
    /** Large right arrow icon */
    var RIGHT_OPEN_BIG:Int = 59517;
    /** Large up arrow icon */
    var UP_OPEN_BIG:Int = 59518;
    /** Down directional icon */
    var DOWN:Int = 59519;
    /** Left directional icon */
    var LEFT:Int = 59520;
    /** Right directional icon */
    var RIGHT:Int = 59521;
    /** Up directional icon */
    var UP:Int = 59522;
    /** Down direction indicator */
    var DOWN_DIR:Int = 59523;
    /** Left direction indicator */
    var LEFT_DIR:Int = 59524;
    /** Right direction indicator */
    var RIGHT_DIR:Int = 59525;
    /** Up direction indicator */
    var UP_DIR:Int = 59526;
    /** Bold down arrow icon */
    var DOWN_BOLD:Int = 59527;
    /** Bold left arrow icon */
    var LEFT_BOLD:Int = 59528;
    /** Bold right arrow icon */
    var RIGHT_BOLD:Int = 59529;
    /** Bold up arrow icon */
    var UP_BOLD:Int = 59530;
    /** Thin down arrow icon */
    var DOWN_THIN:Int = 59531;
    /** Progress bar empty */
    var PROGRESS_0:Int = 59532;
    /** Fast backward/rewind icon */
    var FAST_BACKWARD:Int = 59533;
    /** Fast forward icon */
    var FAST_FORWARD:Int = 59534;
    /** Skip to start icon */
    var TO_START:Int = 59535;
    /** Skip to end icon */
    var TO_END:Int = 59536;
    /** Record button icon */
    var RECORD:Int = 59537;
    /** Pause button icon */
    var PAUSE:Int = 59538;
    /** Stop button icon */
    var STOP:Int = 59539;
    /** Play button icon */
    var PLAY:Int = 59540;
    /** Switch/toggle icon */
    var SWITCH:Int = 59541;
    /** Loop/repeat icon */
    var LOOP:Int = 59542;
    /** Shuffle/random icon */
    var SHUFFLE:Int = 59543;
    /** Level up/increase icon */
    var LEVEL_UP:Int = 59544;
    /** Level down/decrease icon */
    var LEVEL_DOWN:Int = 59545;
    /** Counter-clockwise arrows */
    var ARROWS_CCW:Int = 59546;
    /** Clockwise rotation icon */
    var CW:Int = 59547;
    /** Counter-clockwise rotation icon */
    var CCW:Int = 59548;
    /** Thin up arrow icon */
    var UP_THIN:Int = 59549;
    /** Thin right arrow icon */
    var RIGHT_THIN:Int = 59550;
    /** Thin left arrow icon */
    var LEFT_THIN:Int = 59551;
    /** Progress bar 2/3 full */
    var PROGRESS_2:Int = 59552;
    /** Progress bar 1/3 full */
    var PROGRESS_1:Int = 59553;
    /** Progress bar full */
    var PROGRESS_3:Int = 59554;
    /** Target/crosshair icon */
    var TARGET:Int = 59555;
    /** Color palette icon */
    var PALETTE:Int = 59556;
    /** List/menu icon */
    var LIST:Int = 59557;
    /** Signal strength icon */
    var SIGNAL:Int = 59558;
    /** Add to list icon */
    var LIST_ADD:Int = 59559;
    /** Trophy/achievement icon */
    var TROPHY:Int = 59560;
    /** Battery level icon */
    var BATTERY:Int = 59561;
    /** Go back in time icon */
    var BACK_IN_TIME:Int = 59562;
    /** Computer monitor icon */
    var MONITOR:Int = 59563;
    /** Mobile phone icon */
    var MOBILE:Int = 59564;
    /** Network/connection icon */
    var NETWORK:Int = 59565;
    /** Compact disc icon */
    var CD:Int = 59566;
    /** Inbox/mail tray icon */
    var INBOX:Int = 59567;
    /** Install/setup icon */
    var INSTALL:Int = 59568;
    /** Globe/world icon */
    var GLOBE:Int = 59569;
    /** Cloud/storage icon */
    var CLOUD:Int = 59570;
    /** Storm cloud icon */
    var CLOUD_THUNDER:Int = 59571;
    /** Area chart icon */
    var CHART_AREA:Int = 59572;
    /** Bar chart icon */
    var CHART_BAR:Int = 59573;
    /** Line chart icon */
    var CHART_LINE:Int = 59574;
    /** Pie chart icon */
    var CHART_PIE:Int = 59575;
    /** Eraser/delete icon */
    var ERASE:Int = 59576;
    /** Infinity symbol icon */
    var INFINITY:Int = 59577;
    /** Magnet/attraction icon */
    var MAGNET:Int = 59578;
    /** Paint brush icon */
    var BRUSH:Int = 59579;
    /** Three dots/ellipsis icon */
    var DOT_3:Int = 59580;
    /** Two dots icon */
    var DOT_2:Int = 59581;
    /** Single dot icon */
    var DOT:Int = 59582;
    /** Suitcase/travel icon */
    var SUITCASE:Int = 59583;
    /** Briefcase/business icon */
    var BRIEFCASE:Int = 59584;
    /** Computer mouse icon */
    var MOUSE:Int = 59585;
    /** Life preserver/help icon */
    var LIFEBUOY:Int = 59586;
    /** Leaf/nature icon */
    var LEAF:Int = 59587;
    /** Paper airplane/send icon */
    var PAPER_PLANE:Int = 59588;
    /** Airplane/flight icon */
    var FLIGHT:Int = 59589;
    /** Moon/night mode icon */
    var MOON:Int = 59590;
    /** Lightning/flash icon */
    var FLASH:Int = 59591;
    /** Tape/cassette icon */
    var TAPE:Int = 59592;
    /** Graduation cap/education icon */
    var GRADUATION_CAP:Int = 59593;
    /** Language/translation icon */
    var LANGUAGE:Int = 59594;
    /** Ticket/admission icon */
    var TICKET:Int = 59595;
    /** Water/waves icon */
    var WATER:Int = 59596;
    /** Water droplet icon */
    var DROPLET:Int = 59597;
    /** Air/wind icon */
    var AIR:Int = 59598;
    /** Credit card/payment icon */
    var CREDIT_CARD:Int = 59599;
    /** Floppy disk/save icon */
    var FLOPPY:Int = 59600;
    /** Megaphone/announcement icon */
    var MEGAPHONE:Int = 59601;
    /** Clipboard/copy icon */
    var CLIPBOARD:Int = 59602;
    /** Database/storage icon */
    var DATABASE:Int = 59603;
    /** Hard drive/storage icon */
    var DRIVE:Int = 59604;
    /** Bucket/container icon */
    var BUCKET:Int = 59605;
    /** Thermometer/temperature icon */
    var THERMOMETER:Int = 59606;
    /** Key/access icon */
    var KEY:Int = 59607;
    /** Cascade flow diagram */
    var FLOW_CASCADE:Int = 59608;
    /** Branch flow diagram */
    var FLOW_BRANCH:Int = 59609;
    /** Tree flow diagram */
    var FLOW_TREE:Int = 59610;
    /** Line flow diagram */
    var FLOW_LINE:Int = 59611;
    /** Creative Commons Remix license */
    var CC_REMIX:Int = 59612;
    /** Creative Commons ShareAlike license */
    var CC_SHARE:Int = 59613;
    /** Creative Commons Public Domain */
    var CC_PD:Int = 59614;
    /** Creative Commons Zero license */
    var CC_ZERO:Int = 59615;
    /** Creative Commons No Derivatives license */
    var CC_ND:Int = 59616;
    /** Creative Commons ShareAlike license */
    var CC_SA:Int = 59617;
    /** Creative Commons Non-Commercial Japan license */
    var CC_NC_JP:Int = 59618;
    /** Creative Commons Non-Commercial EU license */
    var CC_NC_EU:Int = 59619;
    /** Creative Commons Non-Commercial license */
    var CC_NC:Int = 59620;
    /** Creative Commons Attribution license */
    var CC_BY:Int = 59621;
    /** Creative Commons license icon */
    var CC:Int = 59622;
    /** Traffic cone/construction icon */
    var TRAFFIC_CONE:Int = 59623;
    /** Gauge/meter icon */
    var GAUGE:Int = 59624;
    /** Rocket/launch icon */
    var ROCKET:Int = 59625;
    /** Parallel flow diagram */
    var FLOW_PARALLEL:Int = 59626;
    /** GitHub logo icon */
    var GITHUB:Int = 62208;
    /** GitHub logo in circle */
    var GITHUB_CIRCLED:Int = 62209;
    /** Flickr logo icon */
    var FLICKR:Int = 62211;
    /** Flickr logo in circle */
    var FLICKR_CIRCLED:Int = 62212;
    /** Vimeo logo icon */
    var VIMEO:Int = 62214;
    /** Vimeo logo in circle */
    var VIMEO_CIRCLED:Int = 62215;
    /** Twitter logo icon */
    var TWITTER:Int = 62217;
    /** Twitter logo in circle */
    var TWITTER_CIRCLED:Int = 62218;
    /** Facebook logo icon */
    var FACEBOOK:Int = 62220;
    /** Facebook logo in circle */
    var FACEBOOK_CIRCLED:Int = 62221;
    /** Facebook logo in square */
    var FACEBOOK_SQUARED:Int = 62222;
    /** Google Plus logo icon */
    var GPLUS:Int = 62223;
    /** Google Plus logo in circle */
    var GPLUS_CIRCLED:Int = 62224;
    /** Pinterest logo icon */
    var PINTEREST:Int = 62226;
    /** Pinterest logo in circle */
    var PINTEREST_CIRCLED:Int = 62227;
    /** Tumblr logo icon */
    var TUMBLR:Int = 62229;
    /** Tumblr logo in circle */
    var TUMBLR_CIRCLED:Int = 62230;
    /** LinkedIn logo icon */
    var LINKEDIN:Int = 62232;
    /** LinkedIn logo in circle */
    var LINKEDIN_CIRCLED:Int = 62233;
    /** Dribbble logo icon */
    var DRIBBBLE:Int = 62235;
    /** Dribbble logo in circle */
    var DRIBBBLE_CIRCLED:Int = 62236;
    /** StumbleUpon logo icon */
    var STUMBLEUPON:Int = 62238;
    /** StumbleUpon logo in circle */
    var STUMBLEUPON_CIRCLED:Int = 62239;
    /** Last.fm logo icon */
    var LASTFM:Int = 62241;
    /** Last.fm logo in circle */
    var LASTFM_CIRCLED:Int = 62242;
    /** Rdio logo icon */
    var RDIO:Int = 62244;
    /** Rdio logo in circle */
    var RDIO_CIRCLED:Int = 62245;
    /** Spotify logo icon */
    var SPOTIFY:Int = 62247;
    /** Spotify logo in circle */
    var SPOTIFY_CIRCLED:Int = 62248;
    /** QQ messenger logo icon */
    var QQ:Int = 62250;
    /** Instagram logo icon */
    var INSTAGRAM:Int = 62253;
    /** Dropbox logo icon */
    var DROPBOX:Int = 62256;
    /** Evernote logo icon */
    var EVERNOTE:Int = 62259;
    /** Flattr logo icon */
    var FLATTR:Int = 62262;
    /** Skype logo icon */
    var SKYPE:Int = 62265;
    /** Skype logo in circle */
    var SKYPE_CIRCLED:Int = 62266;
    /** Renren logo icon */
    var RENREN:Int = 62268;
    /** Sina Weibo logo icon */
    var SINA_WEIBO:Int = 62271;
    /** PayPal logo icon */
    var PAYPAL:Int = 62274;
    /** Picasa logo icon */
    var PICASA:Int = 62277;
    /** SoundCloud logo icon */
    var SOUNDCLOUD:Int = 62280;
    /** Mixi logo icon */
    var MIXI:Int = 62283;
    /** Behance logo icon */
    var BEHANCE:Int = 62286;
    /** Google Circles logo icon */
    var GOOGLE_CIRCLES:Int = 62289;
    /** VKontakte logo icon */
    var VKONTAKTE:Int = 62292;
    /** Smashing Magazine logo icon */
    var SMASHING:Int = 62295;
    /** Database shape icon */
    var DB_SHAPE:Int = 62976;
    /** Sweden flag icon */
    var SWEDEN:Int = 62977;
    /** Daniel Bruce logo icon */
    var LOGO_DB:Int = 62979;
}