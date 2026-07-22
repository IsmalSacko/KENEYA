#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère tous les assets graphiques Google Play pour KENEYA (secteur santé, Mali).
Rendu HTML/CSS via Chrome headless -> PNG aux dimensions exactes exigées.

Sorties (dossier ./out) :
  icon_512.png                 512x512     (icône appli, <1 Mo)
  feature_graphic_1024x500.png 1024x500    (image de présentation, <15 Mo)
  phone_1..6.png               1080x1920   (>=2, 9:16, >=1080)  téléphone
  tablet7_1..2.png             1920x1080   (16:9)               tablette 7"
  tablet10_1..2.png            2560x1440   (16:9, >=1080)       tablette 10"
  chromebook_1..2.png          2560x1440   (16:9)               Chromebook
"""
import os, subprocess, sys, html

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
TMP = os.path.join(HERE, ".build")
os.makedirs(OUT, exist_ok=True)
os.makedirs(TMP, exist_ok=True)

CHROME = "google-chrome"

# ---------------------------------------------------------------- design system
C = dict(
    teal="#0d9488", emerald="#10b981", deep="#0f766e", deeper="#0b5e57",
    ink="#0f172a", slate="#475569", muted="#94a3b8", faint="#cbd5e1",
    bg="#eef2f5", card="#ffffff", line="#e6ebf0",
    danger="#ef4444", amber="#f59e0b", success="#22c55e", sky="#0ea5e9",
)
FONT = "'DejaVu Sans','Noto Sans',sans-serif"
BRAND = "linear-gradient(135deg,#0d9488 0%,#10b981 55%,#34d399 100%)"

def esc(s): return html.escape(s, quote=True)

# ---------------------------------------------------------------- SVG icons
def _svg(inner, size, color, sw=2.1, fill="none", vb=24):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 {vb} {vb}" fill="{fill}" '
            f'stroke="{color}" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-linejoin="round">{inner}</svg>')

ICONS = {
    "cross": '<path d="M12 5v14M5 12h14"/>',
    "pulse": '<path d="M2 12h4l2-6 4 12 2.5-7H22"/>',
    "user": '<circle cx="12" cy="8" r="3.4"/><path d="M5 20c0-3.6 3.1-6 7-6s7 2.4 7 6"/>',
    "users": '<circle cx="9" cy="8" r="3"/><path d="M2.5 20c0-3.3 2.9-5.5 6.5-5.5S15.5 16.7 15.5 20"/><path d="M16 5.2a3 3 0 0 1 0 5.8M17 14.4c2.6.5 4.5 2.4 4.5 5.1"/>',
    "pill": '<rect x="3" y="8.5" width="18" height="7" rx="3.5" transform="rotate(-40 12 12)"/><path d="M8.2 8.2l4 4"/>',
    "cart": '<circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2.5 3h2.2l2 12.2A2 2 0 0 0 8.7 17H18l2-9H6"/>',
    "grid": '<rect x="3" y="3" width="7.5" height="7.5" rx="1.6"/><rect x="13.5" y="3" width="7.5" height="7.5" rx="1.6"/><rect x="3" y="13.5" width="7.5" height="7.5" rx="1.6"/><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="1.6"/>',
    "cash": '<rect x="2.5" y="6" width="19" height="12" rx="2.2"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9v6M18 9v6"/>',
    "bell": '<path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6"/><path d="M10 20a2 2 0 0 0 4 0"/>',
    "search": '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>',
    "lock": '<rect x="4.5" y="10.5" width="15" height="10" rx="2.4"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
    "phone": '<rect x="6.5" y="2.5" width="11" height="19" rx="2.6"/><path d="M10.5 18.5h3"/>',
    "wifioff": '<path d="M2 8.8C5 6.4 8.4 5 12 5c1.2 0 2.4.2 3.5.5M22 8.8a15 15 0 0 0-3-2M5.5 12.4A11 11 0 0 1 9 10.6M18.5 12.4c-.8-.6-1.6-1.1-2.5-1.5M8.8 15.8A6 6 0 0 1 12 15c1.1 0 2.2.3 3.2.8"/><circle cx="12" cy="19.2" r="0.6" fill="'+C["ink"]+'"/><path d="M3 3l18 18"/>',
    "sync": '<path d="M20 8a8 8 0 0 0-13.8-2.6L4 8M4 8V4M4 8h4"/><path d="M4 16a8 8 0 0 0 13.8 2.6L20 16M20 16v4M20 16h-4"/>',
    "check": '<path d="M4 12.5l5 5L20 6"/>',
    "pin": '<path d="M12 22s7-6.3 7-12A7 7 0 0 0 5 10c0 5.7 7 12 7 12z"/><circle cx="12" cy="10" r="2.6"/>',
    "cal": '<rect x="3.5" y="5" width="17" height="16" rx="2.2"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/>',
    "steth": '<path d="M6 3v5a4 4 0 0 0 8 0V3"/><path d="M10 16v1a5 5 0 0 0 10 0v-2"/><circle cx="20" cy="12.5" r="2"/><path d="M6 3H4M6 3h2M14 3h-2M14 3h2"/>',
    "shield": '<path d="M12 2.5l7.5 3v6c0 5-3.3 8.4-7.5 10-4.2-1.6-7.5-5-7.5-10v-6z"/><path d="M8.8 12l2.2 2.2 4.2-4.4"/>',
    "chevron": '<path d="M9 6l6 6-6 6"/>',
}
def ic(name, size=24, color="#0f172a", sw=2.1):
    return _svg(ICONS[name], size, color, sw)

# logo mark : croix médicale blanche + pouls, sur pastille dégradée
def logo_mark(px, radius_ratio=0.26, pulse=True):
    r = int(px*radius_ratio)
    pulse_svg = (f'<polyline points="8,52 26,52 33,34 42,70 49,46 56,52 92,52" '
                 f'fill="none" stroke="rgba(255,255,255,.55)" stroke-width="5.5" '
                 f'stroke-linecap="round" stroke-linejoin="round"/>') if pulse else ""
    return f'''
    <div style="width:{px}px;height:{px}px;border-radius:{r}px;background:{BRAND};
         position:relative;box-shadow:0 {px*0.04}px {px*0.12}px rgba(13,148,136,.45),
         inset 0 2px 6px rgba(255,255,255,.35);overflow:hidden">
      <div style="position:absolute;inset:0;background:radial-gradient(120% 80% at 25% 15%,
           rgba(255,255,255,.30),rgba(255,255,255,0) 55%)"></div>
      <svg viewBox="0 0 100 100" style="position:absolute;inset:0;width:100%;height:100%">
        <g fill="#ffffff">
          <rect x="41" y="20" width="18" height="60" rx="7"/>
          <rect x="20" y="41" width="60" height="18" rx="7"/>
        </g>
        {pulse_svg}
      </svg>
    </div>'''

# ---------------------------------------------------------------- HTML shell
def page(w, h, body, extra_css=""):
    return f'''<!doctype html><html lang="fr"><head><meta charset="utf-8">
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
html,body{{width:{w}px;height:{h}px;overflow:hidden;font-family:{FONT};
  -webkit-font-smoothing:antialiased;color:{C["ink"]}}}
.stage{{width:{w}px;height:{h}px;position:relative;overflow:hidden}}
{extra_css}
</style></head><body><div class="stage">{body}</div></body></html>'''

def render(name, w, h, body, extra_css=""):
    fp_html = os.path.join(TMP, name + ".html")
    fp_png = os.path.join(OUT, name + ".png")
    with open(fp_html, "w", encoding="utf-8") as f:
        f.write(page(w, h, body, extra_css))
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--default-background-color=00000000",
                    f"--window-size={w},{h}", f"--screenshot={fp_png}",
                    "--virtual-time-budget=1200", f"file://{fp_html}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    from PIL import Image
    im = Image.open(fp_png)
    kb = os.path.getsize(fp_png)//1024
    print(f"  {name:26s} {im.size[0]}x{im.size[1]:<5d} {kb} Ko")
    return fp_png

# =============================================================== UI components
def statusbar(dark=False):
    col = "#0f172a" if not dark else "#ffffff"
    return f'''<div style="display:flex;justify-content:space-between;align-items:center;
      padding:16px 34px 6px;font-size:26px;font-weight:700;color:{col}">
      <span>08:24</span>
      <span style="display:flex;gap:12px;align-items:center;font-size:22px;opacity:.9">
        {ic("wifioff",26,col,2.4) if False else ""}▾ 4G ▮▮▮ 87%</span></div>'''

def appbar(title, right=""):
    return f'''<div style="background:{BRAND};padding:22px 30px 26px;color:#fff;
      display:flex;align-items:center;justify-content:space-between;
      box-shadow:0 6px 18px rgba(13,148,136,.30)">
      <div style="font-size:38px;font-weight:800;letter-spacing:.3px">{title}</div>
      <div style="display:flex;gap:18px;align-items:center">{right}</div></div>'''

def stat_card(icon, label, value, tint, sub=""):
    return f'''<div style="background:#fff;border:1px solid {C["line"]};border-radius:26px;
      padding:26px 24px;box-shadow:0 10px 24px rgba(15,23,42,.05)">
      <div style="width:74px;height:74px;border-radius:20px;background:{tint}1a;
        display:flex;align-items:center;justify-content:center;margin-bottom:18px">
        {ic(icon,40,tint,2.3)}</div>
      <div style="font-size:46px;font-weight:800;color:{C['ink']}">{value}</div>
      <div style="font-size:26px;color:{C['slate']};margin-top:4px">{label}</div>
      {f'<div style="font-size:22px;color:{tint};margin-top:6px;font-weight:700">{sub}</div>' if sub else ''}
    </div>'''

def bars(data, hcol):
    mx = max(v for _, v in data)
    cols = ""
    for lbl, v in data:
        hh = int(150*v/mx)+14
        cols += f'''<div style="display:flex;flex-direction:column;align-items:center;gap:12px;flex:1">
          <div style="width:38px;height:{hh}px;border-radius:12px 12px 4px 4px;
            background:{hcol}"></div>
          <div style="font-size:22px;color:{C['muted']}">{lbl}</div></div>'''
    return f'<div style="display:flex;align-items:flex-end;gap:10px;height:210px">{cols}</div>'

def avatar(initials, col):
    return f'''<div style="width:66px;height:66px;border-radius:20px;background:{col}1f;
      color:{col};font-weight:800;font-size:28px;display:flex;align-items:center;
      justify-content:center;flex:0 0 auto">{initials}</div>'''

def list_row(av, title, sub, right="", rc=None):
    rc = rc or C["muted"]
    return f'''<div style="display:flex;align-items:center;gap:22px;padding:22px 4px;
      border-bottom:1px solid {C['line']}">
      {av}
      <div style="flex:1;min-width:0">
        <div style="font-size:31px;font-weight:700;color:{C['ink']}">{title}</div>
        <div style="font-size:25px;color:{C['slate']};margin-top:3px">{sub}</div></div>
      <div style="font-size:25px;font-weight:700;color:{rc}">{right}</div></div>'''

def field(label, value, icon, dots=False):
    inner = ('<div style="display:flex;gap:20px">' +
             ''.join('<div style="width:26px;height:26px;border-radius:50%;background:#0f172a"></div>' for _ in range(4)) +
             '</div>') if dots else f'<span style="font-size:34px;color:{C["ink"]};font-weight:700">{value}</span>'
    return f'''<div style="margin-bottom:30px">
      <div style="font-size:26px;color:{C['slate']};margin-bottom:12px;font-weight:600">{label}</div>
      <div style="display:flex;align-items:center;gap:20px;background:#fff;border:2px solid {C['line']};
        border-radius:20px;padding:26px 28px">
        {ic(icon,34,C['teal'],2.3)}{inner}</div></div>'''

def btn(text, wide=True):
    return f'''<div style="background:{BRAND};color:#fff;font-size:34px;font-weight:800;
      text-align:center;padding:30px;border-radius:22px;
      box-shadow:0 14px 30px rgba(13,148,136,.35);{'width:100%' if wide else ''}">{text}</div>'''

def chip(text, col):
    return f'''<span style="display:inline-flex;align-items:center;gap:10px;background:{col}1a;
      color:{col};font-size:23px;font-weight:700;padding:9px 20px;border-radius:999px">{text}</span>'''

def stockbar(pct, col):
    return f'''<div style="width:100%;height:14px;background:{C['line']};border-radius:999px;overflow:hidden">
      <div style="width:{pct}%;height:100%;background:{col};border-radius:999px"></div></div>'''

# =============================================================== phone screens
SCREEN_W, SCREEN_H = 1080, 1920  # inner app screen (full-bleed device)

def scr_login():
    return f'''<div style="height:100%;background:#f7fafc;display:flex;flex-direction:column">
      {statusbar()}
      <div style="flex:1;display:flex;flex-direction:column;justify-content:center;padding:0 78px">
        <div style="display:flex;justify-content:center;margin-bottom:34px">{logo_mark(168)}</div>
        <div style="text-align:center;font-size:64px;font-weight:900;letter-spacing:2px;color:{C['ink']}">KENEYA</div>
        <div style="text-align:center;font-size:29px;color:{C['slate']};margin:10px 0 60px">Espace professionnel de santé</div>
        {field("Téléphone","76 00 00 01","phone")}
        {field("Code PIN","","lock",dots=True)}
        <div style="margin-top:14px">{btn("Se connecter")}</div>
        <div style="display:flex;align-items:center;justify-content:center;gap:14px;margin-top:44px;color:{C['muted']};font-size:25px">
          {ic("shield",30,C['teal'],2.2)} Données chiffrées · Multi-établissement</div>
      </div></div>'''

def scr_dashboard():
    right = f'<div style="position:relative">{ic("bell",42,"#fff",2.3)}<div style="position:absolute;top:-4px;right:-4px;width:20px;height:20px;background:#f59e0b;border-radius:50%;border:3px solid #10b981"></div></div>'
    return f'''<div style="height:100%;background:{C['bg']};display:flex;flex-direction:column">
      {statusbar()}
      {appbar("Cabinet KENEYA", right)}
      <div style="padding:34px 36px;overflow:hidden">
        <div style="font-size:34px;color:{C['slate']}">Bonjour,</div>
        <div style="font-size:52px;font-weight:900;color:{C['ink']};margin-bottom:34px">Dr Ismaila Sacko</div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:26px;margin-bottom:34px">
          {stat_card("users","Patients","128",C['teal'],"+8 aujourd'hui")}
          {stat_card("steth","Consultations","34",C['sky'],"cette semaine")}
          {stat_card("cash","Recettes","92 500 F",C['emerald'],"aujourd'hui")}
          {stat_card("bell","Stock alerte","5",C['danger'],"ruptures proches")}
        </div>
        <div style="background:#fff;border:1px solid {C['line']};border-radius:28px;padding:32px 34px;
          box-shadow:0 10px 24px rgba(15,23,42,.05)">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:26px">
            <div style="font-size:33px;font-weight:800">Activité de la semaine</div>
            {chip("+18%",C['emerald'])}</div>
          {bars([("Lun",6),("Mar",9),("Mer",5),("Jeu",11),("Ven",8),("Sam",13),("Dim",3)],C['teal'])}
        </div>
      </div></div>'''

def scr_patients():
    rows = ""
    data = [("Awa Traoré","65 12 04 · Bamako","AT",C['teal'],"Suivi"),
            ("Moussa Diarra","76 88 21 · Kati","MD",C['sky'],"Nouveau"),
            ("Fatoumata Keïta","69 30 55 · Bamako","FK",C['emerald'],"Suivi"),
            ("Ibrahim Coulibaly","78 45 12 · Ségou","IC",C['amber'],"Contrôle"),
            ("Kadiatou Sidibé","66 71 09 · Bamako","KS",C['teal'],"Suivi"),
            ("Oumar Cissé","90 22 88 · Koulikoro","OC",C['sky'],"Nouveau")]
    for name, sub, ini, col, tag in data:
        rows += list_row(avatar(ini,col), name, sub, "")+""
    chips = ""
    return f'''<div style="height:100%;background:#fff;display:flex;flex-direction:column">
      {statusbar()}
      {appbar("Patients", ic("search",40,"#fff",2.3))}
      <div style="padding:30px 36px 0">
        <div style="display:flex;align-items:center;gap:20px;background:{C['bg']};border-radius:20px;
          padding:24px 28px;margin-bottom:14px">
          {ic("search",34,C['muted'],2.3)}<span style="font-size:30px;color:{C['muted']}">Rechercher un patient…</span></div>
        <div style="display:flex;gap:14px;margin:20px 0 6px">
          {chip("Tous · 128",C['teal'])}{chip("Suivi",C['slate'])}{chip("Nouveaux",C['slate'])}</div>
        <div>{rows}</div>
      </div>
      <div style="position:absolute;right:48px;bottom:64px;width:112px;height:112px;border-radius:34px;
        background:{BRAND};display:flex;align-items:center;justify-content:center;
        box-shadow:0 18px 36px rgba(13,148,136,.45)">{ic("cross",56,"#fff",2.6)}</div>
    </div>'''

def scr_consultation():
    meds = [("Paracétamol 500mg","1 cp x3 / jour · 5 jours"),
            ("Amoxicilline 1g","1 cp x2 / jour · 7 jours"),
            ("Sérum oral","si besoin")]
    ml = ""
    for m, p in meds:
        ml += f'''<div style="display:flex;align-items:center;gap:20px;padding:20px 0;border-bottom:1px solid {C['line']}">
          {ic("pill",34,C['emerald'],2.3)}<div style="flex:1"><div style="font-size:29px;font-weight:700">{m}</div>
          <div style="font-size:24px;color:{C['slate']}">{p}</div></div></div>'''
    return f'''<div style="height:100%;background:{C['bg']};display:flex;flex-direction:column">
      {statusbar()}
      {appbar("Consultation")}
      <div style="padding:34px 36px">
        <div style="background:#fff;border:1px solid {C['line']};border-radius:26px;padding:28px 30px;
          display:flex;align-items:center;gap:22px;margin-bottom:26px;box-shadow:0 10px 24px rgba(15,23,42,.05)">
          {avatar("AT",C['teal'])}
          <div style="flex:1"><div style="font-size:34px;font-weight:800">Awa Traoré</div>
            <div style="font-size:25px;color:{C['slate']}">F · 34 ans · 65 12 04</div></div>
          {chip("En cours",C['sky'])}</div>
        <div style="background:#fff;border:1px solid {C['line']};border-radius:26px;padding:30px 32px;
          box-shadow:0 10px 24px rgba(15,23,42,.05)">
          <div style="font-size:25px;color:{C['muted']};font-weight:700;margin-bottom:8px">MOTIF</div>
          <div style="font-size:30px;margin-bottom:24px">Fièvre et céphalées depuis 3 jours</div>
          <div style="font-size:25px;color:{C['muted']};font-weight:700;margin-bottom:8px">DIAGNOSTIC</div>
          <div style="font-size:30px;margin-bottom:24px">Paludisme simple confirmé (TDR +)</div>
          <div style="font-size:25px;color:{C['muted']};font-weight:700;margin-bottom:6px">ORDONNANCE</div>
          {ml}
          <div style="display:flex;justify-content:space-between;align-items:center;margin-top:26px">
            <div style="font-size:30px;color:{C['slate']}">Total consultation</div>
            <div style="font-size:40px;font-weight:900;color:{C['ink']}">3 500 F</div></div>
        </div>
      </div></div>'''

def scr_pharmacie():
    data = [("Paracétamol 500mg","Stock 240",78,C['emerald']),
            ("Amoxicilline 1g","Stock 18 · bas",16,C['amber']),
            ("Artéméther/Luméf.","Stock 4 · rupture",8,C['danger']),
            ("Métronidazole","Stock 132",64,C['emerald']),
            ("Oméprazole 20mg","Stock 27 · bas",22,C['amber']),
            ("Sérum salé 0,9%","Stock 96",70,C['teal'])]
    rows = ""
    for name, st, pct, col in data:
        rows += f'''<div style="padding:24px 0;border-bottom:1px solid {C['line']}">
          <div style="display:flex;align-items:center;gap:20px;margin-bottom:14px">
            {ic("pill",34,col,2.3)}
            <div style="flex:1;font-size:30px;font-weight:700">{name}</div>
            <div style="font-size:25px;font-weight:700;color:{col}">{st}</div></div>
          {stockbar(pct,col)}</div>'''
    return f'''<div style="height:100%;background:#fff;display:flex;flex-direction:column">
      {statusbar()}
      {appbar("Pharmacie · Stock", ic("cart",40,"#fff",2.3))}
      <div style="padding:30px 36px 0">
        <div style="display:flex;gap:16px;margin-bottom:16px">
          {chip("2 ruptures",C['danger'])}{chip("2 stocks bas",C['amber'])}</div>
        {rows}
      </div>
      <div style="position:absolute;left:36px;right:36px;bottom:52px">{btn("Nouvelle vente")}</div>
    </div>'''

def scr_offline():
    return f'''<div style="height:100%;background:linear-gradient(180deg,#f7fafc,#eafaf5);
      display:flex;flex-direction:column">
      {statusbar()}
      <div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:0 84px;text-align:center">
        <div style="width:260px;height:260px;border-radius:50%;background:#0d94881a;
          display:flex;align-items:center;justify-content:center;margin-bottom:50px;position:relative">
          <div style="width:190px;height:190px;border-radius:50%;background:#fff;
            display:flex;align-items:center;justify-content:center;box-shadow:0 20px 40px rgba(13,148,136,.20)">
            {ic("wifioff",96,C['teal'],2.2)}</div>
          <div style="position:absolute;bottom:6px;right:22px;width:96px;height:96px;border-radius:50%;
            background:{BRAND};display:flex;align-items:center;justify-content:center;
            box-shadow:0 12px 26px rgba(13,148,136,.45)">{ic("sync",50,"#fff",2.4)}</div>
        </div>
        <div style="font-size:60px;font-weight:900;color:{C['ink']}">Travaillez hors-ligne</div>
        <div style="font-size:33px;color:{C['slate']};line-height:1.5;margin-top:22px">
          Consultations, ventes et paiements restent disponibles <b>sans connexion</b>.
          Tout se synchronise automatiquement au retour du réseau.</div>
        <div style="display:flex;align-items:center;gap:20px;background:#fff;border:1px solid {C['line']};
          border-radius:22px;padding:26px 32px;margin-top:56px;width:100%;box-shadow:0 10px 24px rgba(15,23,42,.05)">
          {ic("check",40,C['success'],2.6)}
          <div style="flex:1;text-align:left"><div style="font-size:30px;font-weight:800">Synchronisé</div>
            <div style="font-size:25px;color:{C['slate']}">12 changements envoyés · il y a 2 min</div></div>
          {chip("À jour",C['success'])}</div>
      </div></div>'''

PHONE_SCREENS = [
    ("phone_1", "Connexion sécurisée", "Téléphone + code PIN, données chiffrées", scr_login),
    ("phone_2", "Pilotez votre établissement", "Tableau de bord en temps réel", scr_dashboard),
    ("phone_3", "Dossiers patients centralisés", "Recherche instantanée · multi-établissement", scr_patients),
    ("phone_4", "Consultations & ordonnances", "Du diagnostic au paiement", scr_consultation),
    ("phone_5", "Pharmacie & gestion de stock", "Alertes de rupture, ventes rapides", scr_pharmacie),
    ("phone_6", "100 % hors-ligne", "Synchronisation automatique", scr_offline),
]

# marketing frame : caption + device
CAP_BG = [
    "linear-gradient(160deg,#0d9488,#0f766e)",
    "linear-gradient(160deg,#10b981,#0d9488)",
    "linear-gradient(160deg,#0e7490,#0d9488)",
    "linear-gradient(160deg,#0f766e,#155e63)",
    "linear-gradient(160deg,#059669,#0d9488)",
    "linear-gradient(160deg,#0d9488,#0e7490)",
]

def phone_marketing(idx, headline, sub, screen_html):
    bg = CAP_BG[idx % len(CAP_BG)]
    # téléphone : écran complet mis à l'échelle dans un cadre plus grand, remonté
    dev_w = 772
    scale = dev_w / SCREEN_W
    scr_h = int(SCREEN_H * scale)            # hauteur écran complète (1920 -> ~1372)
    inner = f'''<div style="width:{SCREEN_W}px;height:{SCREEN_H}px;transform:scale({scale});
      transform-origin:top left">{screen_html}</div>'''
    return f'''
    <div style="position:absolute;inset:0;background:{bg}"></div>
    <div style="position:absolute;top:-120px;right:-120px;width:520px;height:520px;border-radius:50%;
      background:rgba(255,255,255,.08)"></div>
    <div style="position:absolute;bottom:-160px;left:-140px;width:480px;height:480px;border-radius:50%;
      background:rgba(255,255,255,.06)"></div>
    <div style="position:absolute;top:92px;left:0;right:0;padding:0 90px;text-align:center;color:#fff">
      <div style="font-size:70px;font-weight:900;line-height:1.1;letter-spacing:.3px">{headline}</div>
      <div style="font-size:36px;font-weight:600;opacity:.92;margin-top:18px">{sub}</div>
    </div>
    <div style="position:absolute;left:50%;top:452px;transform:translateX(-50%);
      width:{dev_w+28}px;height:{scr_h+28}px;background:#0f172a;border-radius:64px;
      padding:14px;box-shadow:0 40px 90px rgba(0,0,0,.35)">
      <div style="width:{dev_w}px;height:{scr_h}px;border-radius:50px;overflow:hidden;background:#fff">
        {inner}
      </div></div>'''

# =============================================================== tablet / chromebook (two-pane app)
def sidebar(active):
    items = [("grid","Tableau de bord"),("users","Patients"),("steth","Consultations"),
             ("pill","Pharmacie"),("cart","Ventes"),("cash","Paiements")]
    lis = ""
    for name, label in items:
        on = (label == active)
        lis += f'''<div style="display:flex;align-items:center;gap:20px;padding:20px 24px;border-radius:18px;
          margin-bottom:8px;{'background:#0d94881a;' if on else ''}">
          {ic(name,34,C['teal'] if on else C['slate'],2.3)}
          <span style="font-size:29px;font-weight:{800 if on else 600};color:{C['teal'] if on else C['slate']}">{label}</span></div>'''
    return f'''<div style="width:400px;background:#fff;border-right:1px solid {C['line']};padding:36px 26px;
      display:flex;flex-direction:column">
      <div style="display:flex;align-items:center;gap:20px;padding:0 10px 34px">
        {logo_mark(86)}<div><div style="font-size:40px;font-weight:900;letter-spacing:1px">KENEYA</div>
        <div style="font-size:23px;color:{C['muted']}">Cabinet Bamako</div></div></div>
      {lis}
      <div style="margin-top:auto;display:flex;align-items:center;gap:18px;padding:22px 20px;
        background:{C['bg']};border-radius:18px">{avatar("IS",C['teal'])}
        <div><div style="font-size:27px;font-weight:800">Dr I. Sacko</div>
        <div style="font-size:22px;color:{C['muted']}">Administrateur</div></div></div>
    </div>'''

def tablet_dashboard(w, h):
    main = f'''<div style="flex:1;padding:44px 52px;overflow:hidden">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:36px">
        <div><div style="font-size:34px;color:{C['slate']}">Bonjour,</div>
          <div style="font-size:54px;font-weight:900">Dr Ismaila Sacko</div></div>
        <div style="display:flex;gap:18px">{chip("Aujourd'hui",C['teal'])}
          <div style="width:74px;height:74px;border-radius:20px;background:#fff;border:1px solid {C['line']};
            display:flex;align-items:center;justify-content:center">{ic("bell",38,C['slate'],2.3)}</div></div></div>
      <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:26px;margin-bottom:34px">
        {stat_card("users","Patients","128",C['teal'],"+8 aujourd'hui")}
        {stat_card("steth","Consultations","34",C['sky'],"cette semaine")}
        {stat_card("cash","Recettes","92 500 F",C['emerald'],"aujourd'hui")}
        {stat_card("bell","Stock alerte","5",C['danger'],"ruptures proches")}
      </div>
      <div style="display:grid;grid-template-columns:1.4fr 1fr;gap:26px">
        <div style="background:#fff;border:1px solid {C['line']};border-radius:28px;padding:34px">
          <div style="font-size:33px;font-weight:800;margin-bottom:26px">Activité de la semaine</div>
          {bars([("Lun",6),("Mar",9),("Mer",5),("Jeu",11),("Ven",8),("Sam",13),("Dim",3)],C['teal'])}</div>
        <div style="background:#fff;border:1px solid {C['line']};border-radius:28px;padding:34px">
          <div style="font-size:33px;font-weight:800;margin-bottom:18px">Derniers patients</div>
          {list_row(avatar("AT",C['teal']),"Awa Traoré","Consultation","")}
          {list_row(avatar("MD",C['sky']),"Moussa Diarra","Nouveau","")}
          {list_row(avatar("FK",C['emerald']),"Fatoumata Keïta","Contrôle","")}
        </div></div></div>'''
    return f'<div style="height:100%;display:flex;background:{C["bg"]}">{sidebar("Tableau de bord")}{main}</div>'

def tablet_patients(w, h):
    rows = ""
    for name, sub, ini, col in [("Awa Traoré","65 12 04 · Bamako","AT",C['teal']),
                                ("Moussa Diarra","76 88 21 · Kati","MD",C['sky']),
                                ("Fatoumata Keïta","69 30 55 · Bamako","FK",C['emerald']),
                                ("Ibrahim Coulibaly","78 45 12 · Ségou","IC",C['amber']),
                                ("Kadiatou Sidibé","66 71 09 · Bamako","KS",C['teal'])]:
        rows += list_row(avatar(ini,col),name,sub, "")
    detail = f'''<div style="flex:1;padding:44px 52px">
      <div style="display:flex;align-items:center;gap:26px;margin-bottom:30px">
        {avatar("AT",C['teal'])}
        <div style="flex:1"><div style="font-size:46px;font-weight:900">Awa Traoré</div>
          <div style="font-size:28px;color:{C['slate']}">F · 34 ans · 65 12 04 · Bamako</div></div>
        {chip("Suivi",C['teal'])}</div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:26px">
        {stat_card("steth","Consultations","6",C['sky'])}
        {stat_card("cash","Total payé","21 500 F",C['emerald'])}</div>
      <div style="background:#fff;border:1px solid {C['line']};border-radius:26px;padding:32px">
        <div style="font-size:31px;font-weight:800;margin-bottom:10px">Dernière consultation</div>
        <div style="font-size:27px;color:{C['slate']};margin-bottom:18px">12/07/2026 · Paludisme simple (TDR +)</div>
        <div style="display:flex;gap:16px">{chip("Paracétamol",C['emerald'])}{chip("Amoxicilline",C['emerald'])}</div></div>
    </div>'''
    listpane = f'''<div style="width:560px;background:#fff;border-right:1px solid {C['line']};padding:34px 30px">
      <div style="font-size:40px;font-weight:900;margin-bottom:20px">Patients</div>
      <div style="display:flex;align-items:center;gap:18px;background:{C['bg']};border-radius:18px;
        padding:20px 24px;margin-bottom:12px">{ic("search",32,C['muted'],2.3)}
        <span style="font-size:27px;color:{C['muted']}">Rechercher…</span></div>
      {rows}</div>'''
    return f'<div style="height:100%;display:flex;background:{C["bg"]}">{sidebar("Patients")}{listpane}{detail}</div>'

def tablet_marketing(headline, sub, app_html):
    return f'''
    <div style="position:absolute;inset:0;background:{BRAND}"></div>
    <div style="position:absolute;top:-160px;right:-120px;width:620px;height:620px;border-radius:50%;background:rgba(255,255,255,.08)"></div>
    <div style="position:absolute;top:58px;left:0;right:0;text-align:center;color:#fff">
      <div style="font-size:60px;font-weight:900">{headline}</div>
      <div style="font-size:32px;opacity:.92;margin-top:12px">{sub}</div></div>
    <div style="position:absolute;left:50%;top:230px;transform:translateX(-50%);
      width:calc(100% - 200px);height:calc(100% - 300px);background:#0f172a;border-radius:42px;padding:16px;
      box-shadow:0 40px 90px rgba(0,0,0,.35)">
      <div style="width:100%;height:100%;border-radius:30px;overflow:hidden;background:{C['bg']}">{app_html}</div></div>'''

# =============================================================== icon & feature
def build_icon():
    body = f'<div style="width:512px;height:512px;background:{BRAND};position:relative">' \
           f'<div style="position:absolute;inset:0;background:radial-gradient(120% 90% at 26% 12%,rgba(255,255,255,.30),rgba(255,255,255,0) 55%)"></div>' \
           f'<svg viewBox="0 0 100 100" style="position:absolute;inset:0;width:100%;height:100%">' \
           f'<g fill="#ffffff"><rect x="40" y="17" width="20" height="66" rx="8"/><rect x="17" y="40" width="66" height="20" rx="8"/></g>' \
           f'<polyline points="6,54 24,54 31,33 41,73 49,44 57,54 94,54" fill="none" stroke="rgba(255,255,255,.5)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>' \
           f'</svg></div>'
    render("icon_512", 512, 512, body)

def build_feature():
    body = f'''
    <div style="position:absolute;inset:0;background:{BRAND}"></div>
    <div style="position:absolute;top:-80px;right:180px;width:360px;height:360px;border-radius:50%;background:rgba(255,255,255,.08)"></div>
    <div style="position:absolute;bottom:-140px;right:-60px;width:340px;height:340px;border-radius:50%;background:rgba(255,255,255,.07)"></div>
    <div style="position:absolute;left:64px;top:0;bottom:0;display:flex;flex-direction:column;justify-content:center;color:#fff;width:640px">
      <div style="display:flex;align-items:center;gap:22px;margin-bottom:26px">
        {logo_mark(92,pulse=False)}
        <div style="font-size:78px;font-weight:900;letter-spacing:3px">KENEYA</div></div>
      <div style="font-size:40px;font-weight:800;line-height:1.2">La santé connectée au Mali</div>
      <div style="font-size:27px;opacity:.92;margin-top:14px;line-height:1.5">Cabinets & pharmacies : patients, consultations,<br>stock et paiements — même hors-ligne.</div>
      <div style="display:flex;gap:14px;margin-top:30px">
        {chip("Multi-établissement","#ffffff").replace(C['ink'],"#fff").replace("1a","33")}
      </div>
    </div>
    <div style="position:absolute;right:70px;top:50%;transform:translateY(-50%);
      width:250px;height:430px;background:#0f172a;border-radius:36px;padding:10px;box-shadow:0 30px 70px rgba(0,0,0,.35)">
      <div style="width:230px;height:410px;border-radius:28px;overflow:hidden;background:#fff">
        <div style="transform:scale(0.2130);transform-origin:top left;width:1080px;height:1920px">{scr_dashboard()}</div>
      </div></div>'''
    render("feature_graphic_1024x500", 1024, 500, body)

# =============================================================== run all
def main():
    print("Icône & image de présentation :")
    build_icon()
    build_feature()

    print("Captures téléphone (1080x1920) :")
    for i,(name,h1,h2,fn) in enumerate(PHONE_SCREENS):
        render(name, 1080, 1920, phone_marketing(i,h1,h2,fn()))

    print("Captures tablette 7\" (1920x1080) :")
    render("tablet7_1", 1920, 1080, tablet_marketing("Vue d'ensemble sur grand écran","Interface deux volets pour tablette", tablet_dashboard(1920,1080)))
    render("tablet7_2", 1920, 1080, tablet_marketing("Dossiers patients maître-détail","Liste + fiche patient côte à côte", tablet_patients(1920,1080)))

    print("Captures tablette 10\" (2560x1440) :")
    render("tablet10_1", 2560, 1440, tablet_marketing("Vue d'ensemble sur grand écran","Interface deux volets pour tablette", tablet_dashboard(2560,1440)))
    render("tablet10_2", 2560, 1440, tablet_marketing("Dossiers patients maître-détail","Liste + fiche patient côte à côte", tablet_patients(2560,1440)))

    print("Captures Chromebook (2560x1440) :")
    render("chromebook_1", 2560, 1440, tablet_marketing("Pensé aussi pour le grand écran","Gérez votre établissement depuis un Chromebook", tablet_dashboard(2560,1440)))
    render("chromebook_2", 2560, 1440, tablet_marketing("Recherche patient instantanée","Toutes les données au même endroit", tablet_patients(2560,1440)))

    print("\nTerminé →", OUT)

if __name__ == "__main__":
    main()
