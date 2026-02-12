from __future__ import annotations

import io
import os
import random
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "images"
ASSETS.mkdir(parents=True, exist_ok=True)

PRIMARY = (79, 70, 229)
TEAL = (20, 184, 166)
WHITE = (255, 255, 255)
DARK = (15, 23, 42)
MUTED = (100, 116, 139)


def load_font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = [
        "C:/Windows/Fonts/seguiemj.ttf",
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def gradient_bg(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size, top)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        r = int(top[0] * (1 - t) + bottom[0] * t)
        g = int(top[1] * (1 - t) + bottom[1] * t)
        b = int(top[2] * (1 - t) + bottom[2] * t)
        draw.line((0, y, w, y), fill=(r, g, b))
    return img


def fetch_photo() -> Image.Image | None:
    urls = [
        "https://source.unsplash.com/1600x1000/?mali,man,doctor",
        "https://source.unsplash.com/1600x1000/?african,man,pharmacist",
        "https://source.unsplash.com/1600x1000/?african,man,healthcare",
        "https://source.unsplash.com/1600x1000/?mali,man,clinic",
    ]
    random.shuffle(urls)
    headers = {"User-Agent": "Mozilla/5.0"}
    for url in urls:
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
            img = Image.open(io.BytesIO(data)).convert("RGB")
            return img
        except Exception:
            continue
    return None


def cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    tw, th = size
    iw, ih = img.size
    scale = max(tw / iw, th / ih)
    nw, nh = int(iw * scale), int(ih * scale)
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def add_title_block(img: Image.Image, title: str, subtitle: str | None = None) -> Image.Image:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    w, h = img.size
    d.rounded_rectangle((40, h - 290, w - 40, h - 40), radius=26, fill=(255, 255, 255, 225))

    ft_title = load_font(56, bold=True)
    ft_sub = load_font(34)
    d.text((76, h - 250), title, font=ft_title, fill=DARK)
    if subtitle:
        d.text((76, h - 170), subtitle, font=ft_sub, fill=MUTED)
    return Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")


def draw_logo():
    canvas = Image.new("RGBA", (1900, 700), (255, 255, 255, 0))
    d = ImageDraw.Draw(canvas)

    badge = Image.new("RGBA", (420, 420), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    for i in range(420):
        t = i / 419
        r = int(PRIMARY[0] * (1 - t) + TEAL[0] * t)
        g = int(PRIMARY[1] * (1 - t) + TEAL[1] * t)
        b = int(PRIMARY[2] * (1 - t) + TEAL[2] * t)
        bd.line((0, i, 420, i), fill=(r, g, b, 255))

    mask = Image.new("L", (420, 420), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, 419, 419), radius=110, fill=255)
    canvas.paste(badge, (60, 140), mask)

    d.rounded_rectangle((80, 160, 460, 540), radius=100, outline=(255, 255, 255, 120), width=4)
    d.ellipse((170, 250, 370, 450), fill=WHITE)
    d.rectangle((257, 285, 283, 415), fill=PRIMARY)
    d.rectangle((210, 332, 330, 358), fill=PRIMARY)

    ft_big = load_font(170, bold=True)
    ft_small = load_font(52)
    d.text((520, 188), "KENEYA+", font=ft_big, fill=DARK)
    d.text((530, 390), "Sante connectee pour le Mali", font=ft_small, fill=(39, 106, 137))
    canvas.save(ASSETS / "logo_keneya_plus_principal.png")

    icon = Image.new("RGBA", (1024, 1024), (255, 255, 255, 0))
    di = ImageDraw.Draw(icon)
    for y in range(1024):
        t = y / 1023
        r = int(PRIMARY[0] * (1 - t) + TEAL[0] * t)
        g = int(PRIMARY[1] * (1 - t) + TEAL[1] * t)
        b = int(PRIMARY[2] * (1 - t) + TEAL[2] * t)
        di.line((0, y, 1024, y), fill=(r, g, b, 255))
    m = Image.new("L", (1024, 1024), 0)
    dm = ImageDraw.Draw(m)
    dm.rounded_rectangle((40, 40, 984, 984), radius=240, fill=255)
    rounded = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    rounded.paste(icon, (0, 0), m)
    icon = rounded
    di = ImageDraw.Draw(icon)
    di.ellipse((270, 270, 754, 754), fill=WHITE)
    di.rectangle((484, 360, 540, 664), fill=PRIMARY)
    di.rectangle((370, 484, 654, 540), fill=PRIMARY)
    di.rounded_rectangle((70, 70, 954, 954), radius=220, outline=(255, 255, 255, 96), width=8)
    icon.save(ASSETS / "logo_keneya_plus_icon.png")
    icon.save(ASSETS / "app_icon_1024.png")


def make_splash(name: str, size: tuple[int, int], title: str, subtitle: str):
    base = gradient_bg(size, PRIMARY, TEAL).convert("RGB")
    photo = fetch_photo()
    if photo is not None:
        p = cover(photo, size)
        p = ImageEnhance.Color(p).enhance(1.05)
        p = ImageEnhance.Brightness(p).enhance(0.90)
        veil = Image.new("RGBA", size, (20, 30, 60, 95))
        merged = Image.alpha_composite(p.convert("RGBA"), veil).convert("RGB")
        base = Image.blend(base, merged, 0.68)
    img = add_title_block(base, title, subtitle)
    img.save(ASSETS / name)


def make_onboarding(name: str, title: str, subtitle: str):
    size = (1200, 1800)
    base = gradient_bg(size, PRIMARY, TEAL).convert("RGB")
    photo = fetch_photo()
    if photo is not None:
        p = cover(photo, (1000, 900)).filter(ImageFilter.GaussianBlur(0.2))
        card = Image.new("RGBA", (1040, 980), (255, 255, 255, 225))
        mask = Image.new("L", (1040, 980), 0)
        dm = ImageDraw.Draw(mask)
        dm.rounded_rectangle((0, 0, 1039, 979), radius=56, fill=255)
        card.paste(p, (20, 20))
        base_rgba = base.convert("RGBA")
        base_rgba.paste(card, (80, 260), mask)
        base = base_rgba.convert("RGB")
    img = add_title_block(base, title, subtitle)
    img.save(ASSETS / name)


def make_misc():
    defs = [
        ("welcome_header.png", (1600, 700), "Bienvenue sur KENEYA+", "Sante moderne et fiable"),
        ("empty_patients.png", (1200, 900), "Patients", "Aucun patient enregistre"),
        ("empty_medicaments.png", (1200, 900), "Medicaments", "Aucun medicament en stock"),
        ("empty_etablissements.png", (1200, 900), "Etablissements", "Aucun etablissement"),
        ("empty_utilisateurs.png", (1200, 900), "Utilisateurs", "Aucun utilisateur"),
        ("offline_network_error.png", (1200, 900), "Mode hors connexion", "Synchronisation automatique au retour internet"),
        ("social_preview_1200x630.png", (1200, 630), "KENEYA+", "Gestion sante offline-first"),
        ("store_banner.png", (2400, 1200), "KENEYA+", "Cabinets, cliniques et pharmacies"),
    ]

    for name, size, t, s in defs:
        make_splash(name, size, t, s)


def main():
    draw_logo()

    splash_texts = [
        ("splash_1_android_1080x2400.png", (1080, 2400), "Bienvenue sur KENEYA+", "La solution simple pour gerer vos activites medicales."),
        ("splash_1_ios_1290x2796.png", (1290, 2796), "Bienvenue sur KENEYA+", "La solution simple pour gerer vos activites medicales."),
        ("splash_2_android_1080x2400.png", (1080, 2400), "Patients centralises", "Retrouvez rapidement les informations essentielles."),
        ("splash_2_ios_1290x2796.png", (1290, 2796), "Patients centralises", "Retrouvez rapidement les informations essentielles."),
        ("splash_3_android_1080x2400.png", (1080, 2400), "Medicaments et stock", "Suivez vos stocks et evitez les ruptures."),
        ("splash_3_ios_1290x2796.png", (1290, 2796), "Medicaments et stock", "Suivez vos stocks et evitez les ruptures."),
        ("splash_4_android_1080x2400.png", (1080, 2400), "Etablissements et equipe", "Pilotez votre structure en toute serenite."),
        ("splash_4_ios_1290x2796.png", (1290, 2796), "Etablissements et equipe", "Pilotez votre structure en toute serenite."),
    ]
    for name, size, title, subtitle in splash_texts:
        make_splash(name, size, title, subtitle)

    onboarding = [
        ("onboarding_1.png", "Bienvenue sur KENEYA+", "La solution simple pour gerer vos activites medicales."),
        ("onboarding_2.png", "Patients centralises", "Retrouvez rapidement les informations essentielles."),
        ("onboarding_3.png", "Medicaments et stock", "Suivez vos stocks et evitez les ruptures."),
        ("onboarding_4.png", "Etablissements et equipe", "Pilotez votre structure en toute serenite."),
    ]
    for name, title, subtitle in onboarding:
        make_onboarding(name, title, subtitle)

    make_misc()
    print(f"Assets generated in {ASSETS}")


if __name__ == "__main__":
    main()
