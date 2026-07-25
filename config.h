/* See LICENSE file for copyright and license details. */

/* appearance */
static const unsigned int refresh_rate    = 180;
static const unsigned int enable_noborder = 1;
static const int cursorwarp               = 1;
static const unsigned int snap            = 26;
static const int swallowfloating          = 1;
static const int showbar                  = 1;
static const int topbar                   = 1;
#define ICONSIZE 17
#define ICONSPACING 5
#define SHOWWINICON 1
static const char *fonts[] = { "JetBrainsMono Nerd Font Medium:size=11", "NotoColorEmoji:pixelsize=14" };

/* colors */
static const char col_bg[]     = "#1e1e2e";
static const char col_fg[]     = "#cdd6f4";
static const char col_border[] = "#313244";
static const char col_accent[] = "#89b4fa";
static const char col_selbg[]  = "#313244";
static const char *colors[][3] = {
	/*               fg          bg          border     */
	[SchemeNorm] = { col_fg,     col_bg,     col_border },
	[SchemeSel]  = { col_accent, col_selbg,  col_accent },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5", "6", "7", "8", "9" };

/* rules */
static const Rule rules[] = {
	/* class        instance  title       tags mask  isfloating  isterminal  noswallow  monitor */
	{ "Ghostty",    NULL,     NULL,       0,         0,          1,          0,         -1 },
	{ "firefox",    NULL,     NULL,       0,         0,          0,          1,         -1 },
	{ "Thunar",     NULL,     NULL,       0,         1,          0,          0,         -1 },
};

/* layout(s) */
static const float mfact        = 0.55;
static const int nmaster        = 1;
static const int resizehints    = 1;
static const int lockfullscreen = 1;

static const Layout layouts[] = {
	{ "[]=",  tile   },  /* first entry is default */
	{ "><>",  NULL   },  /* no layout = floating */
	{ "[M]",  monocle },
};

/* key definitions */
#define MODKEY Mod4Mask
#define STATUSBAR "dwmblocks"
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY, view,       {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY, toggleview, {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY, tag,        {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY, toggletag,  {.ui = 1 << TAG} },

/* commands */
static const char *termcmd[]  = { "ghostty", NULL };
static const char *filecmd[]  = { "thunar", NULL };
static const char *webcmd[]   = { "firefox", NULL };

static const Key keys[] = {
    /* modifier                     key          function        argument */

    /* applications */
    { MODKEY,                       XK_x,        spawn,          {.v = termcmd } },
    { MODKEY,                       XK_e,        spawn,          {.v = filecmd } },
    { MODKEY,                       XK_w,        spawn,          {.v = webcmd  } },
	/* keyboard layout toggle (Super+Space) */
	{ MODKEY,                       XK_k,        spawn,          SHCMD("~/.local/bin/sb-kbdtoggle") },

	/* volume */
	{ MODKEY,                       XK_F9,       spawn,          SHCMD("pamixer -d 5;  pkill -RTMIN+11 dwmblocks") },
	{ MODKEY,                       XK_F10,      spawn,          SHCMD("pamixer -i 5;  pkill -RTMIN+11 dwmblocks") },
	{ MODKEY,                       XK_F11,      spawn,          SHCMD("pamixer -t;    pkill -RTMIN+11 dwmblocks") },

	/* layouts */
	{ MODKEY,                       XK_t,        setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_f,        setlayout,      {.v = &layouts[1]} },
	{ MODKEY,                       XK_m,        setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_space,    setlayout,      {0} },
	{ MODKEY|ShiftMask,             XK_space,    togglefloating, {0} },

	/* window management */
	{ MODKEY,                       XK_j,        focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_i,        focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_h,        setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,        setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Return,   zoom,           {0} },
	{ MODKEY,                       XK_Tab,      view,           {0} },
	{ MODKEY|ShiftMask,             XK_c,        killclient,     {0} },
	{ MODKEY,                       XK_0,        view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,        tag,            {.ui = ~0 } },

	/* bar */
	{ MODKEY,                       XK_b,        togglebar,      {0} },

	/* quit */
	{ MODKEY|ShiftMask,             XK_q,        quit,           {0} },

	/* tags */
	TAGKEYS(XK_1, 0)
	TAGKEYS(XK_2, 1)
	TAGKEYS(XK_3, 2)
	TAGKEYS(XK_4, 3)
	TAGKEYS(XK_5, 4)
	TAGKEYS(XK_6, 5)
	TAGKEYS(XK_7, 6)
	TAGKEYS(XK_8, 7)
	TAGKEYS(XK_9, 8)
};

/* button definitions */
static const Button buttons[] = {
	{ ClkLtSymbol,  0,      Button1, setlayout,      {0} },
	{ ClkLtSymbol,  0,      Button3, setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,  0,      Button2, zoom,           {0} },
	{ ClkClientWin, MODKEY, Button1, movemouse,      {0} },
	{ ClkClientWin, MODKEY, Button2, togglefloating, {0} },
	{ ClkClientWin, MODKEY, Button3, resizemouse,    {0} },
	{ ClkTagBar,    0,      Button1, view,           {0} },
	{ ClkTagBar,    0,      Button3, toggleview,     {0} },
	{ ClkTagBar,    MODKEY, Button1, tag,            {0} },
	{ ClkTagBar,    MODKEY, Button3, toggletag,      {0} },
};
