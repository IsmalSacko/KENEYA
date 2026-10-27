"""Fabrique la marque Ngoni Santé : icône, écran de démarrage, visuels Play.

    outils/polices.sh       # une fois : Poppins et Nunito Sans
    python3 outils/marque.py
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

L'emblème est celui de l'application (l'avatar des cartes de tête) : une croix
médicale jaune dans un anneau jaune, sur le bleu nuit de la famille Ngoni
(Ngoni Caisse, Ngoni Atelier, Ngoni Tontine). Tout est dessiné ici, à quatre
fois la taille puis réduit, pour des bords nets.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PROJET = Path(__file__).resolve().parent.parent
POLICES = PROJET / 'outils/polices'

NGONI = (0x0F, 0x2A, 0x5C)
NGONI_HAUT = (0x22, 0x49, 0x8F)
NGONI_BAS = (0x0E, 0x1F, 0x4A)
JAUNE = (0xFF, 0xCC, 0x1F)
BLANC = (0xFF, 0xFF, 0xFF)

NOM = 'Ngoni Santé'
SUR = 4  # suréchantillonnage


def degrade(largeur, hauteur, haut=NGONI_HAUT, bas=NGONI_BAS, diagonal=False):
    """Le dégradé des cartes de tête : clair en haut (à gauche), profond en bas."""
    im = Image.new('RGB', (largeur, hauteur))
    px = im.load()
    for y in range(hauteur):
        for x in range(largeur) if diagonal else [0]:
            t = (x / largeur * 0.6 + y / hauteur * 0.4) if diagonal else y / hauteur
            c = tuple(round(h + (b - h) * t) for h, b in zip(haut, bas))
            if diagonal:
                px[x, y] = c
            else:
                for xx in range(largeur):
                    px[xx, y] = c
    return im


def embleme(taille, fond_anneau=NGONI):
    """L'anneau jaune et la croix, sur fond transparent, à [taille] pixels."""
    t = taille * SUR
    im = Image.new('RGBA', (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    marge = t * 0.04
    epaisseur = t * 0.085
    # L'anneau : un disque jaune, puis l'intérieur bleu nuit.
    d.ellipse([marge, marge, t - marge, t - marge], fill=JAUNE)
    d.ellipse(
        [marge + epaisseur, marge + epaisseur, t - marge - epaisseur, t - marge - epaisseur],
        fill=fond_anneau,
    )
    # La croix médicale, branches arrondies.
    bras = t * 0.15
    long = t * 0.50
    c = t / 2
    r = bras * 0.28
    d.rounded_rectangle([c - bras / 2, c - long / 2, c + bras / 2, c + long / 2], r, fill=JAUNE)
    d.rounded_rectangle([c - long / 2, c - bras / 2, c + long / 2, c + bras / 2], r, fill=JAUNE)
    return im.resize((taille, taille), Image.LANCZOS)


def icone(taille):
    """L'icône pleine : tuile bleu nuit en dégradé, emblème au centre."""
    fond = degrade(taille, taille).convert('RGBA')
    e = embleme(round(taille * 0.62))
    pos = ((taille - e.width) // 2, (taille - e.height) // 2)
    # Un halo jaune très doux derrière l'anneau, comme sur les cartes de tête.
    halo = Image.new('RGBA', (taille, taille), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    m = taille * 0.17
    hd.ellipse([m, m, taille - m, taille - m], fill=JAUNE + (70,))
    halo = halo.filter(ImageFilter.GaussianBlur(taille * 0.05))
    fond.alpha_composite(halo)
    fond.alpha_composite(e, pos)
    return fond


def premier_plan(taille=1024):
    """Le premier plan de l'icône adaptative et de l'écran de démarrage :
    l'emblème dans la zone sûre (les deux tiers du centre), fond transparent."""
    im = Image.new('RGBA', (taille, taille), (0, 0, 0, 0))
    e = embleme(round(taille * 0.46))
    im.alpha_composite(e, ((taille - e.width) // 2, (taille - e.height) // 2))
    return im


def police(nom, taille):
    return ImageFont.truetype(str(POLICES / nom), taille)


def presentation():
    """L'image de présentation Play, 1024 × 500."""
    l, h = 1024 * 2, 500 * 2
    im = degrade(l, h, diagonal=True).convert('RGBA')
    d = ImageDraw.Draw(im)

    # Deux grands cercles bleu clair, à droite, pour la profondeur.
    deco = Image.new('RGBA', (l, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(deco)
    clair = (0x5B, 0x83, 0xD0)
    dd.ellipse([l * 0.70, -h * 0.35, l * 1.25, h * 0.75], outline=clair + (70,), width=18)
    dd.ellipse([l * 0.80, h * 0.45, l * 1.15, h * 1.25], outline=clair + (45,), width=12)
    im.alpha_composite(deco)

    ic = icone(380)
    masque = Image.new('L', ic.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle([0, 0, ic.width, ic.height], 86, fill=255)
    ombre = Image.new('RGBA', (ic.width + 80, ic.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).rounded_rectangle([40, 56, ic.width + 40, ic.height + 56], 90, fill=(0, 0, 0, 110))
    ombre = ombre.filter(ImageFilter.GaussianBlur(24))
    x, y = 120, (h - ic.height) // 2
    im.alpha_composite(ombre, (x - 40, y - 40))
    im.paste(ic, (x, y), masque)

    tx = x + ic.width + 90
    d.text((tx, 250), NOM, font=police('Poppins-ExtraBold.ttf', 132), fill=BLANC)
    d.rounded_rectangle([tx, 440, tx + 150, 452], 6, fill=JAUNE)
    d.text((tx, 490), 'Le centre de santé dans une seule app', font=police('NunitoSans-Bold.ttf', 58), fill=BLANC)
    d.text(
        (tx, 580),
        'Patients · File d’attente · Consultation · Labo\nMaternité · Hospitalisation · Caisse · Pharmacie',
        font=police('NunitoSans-SemiBold.ttf', 42),
        fill=(0xDC, 0xE4, 0xF2),
        spacing=14,
    )
    return im.convert('RGB').resize((1024, 500), Image.LANCZOS)


def main():
    images = PROJET / 'assets/images'
    store = PROJET / 'store'
    store.mkdir(exist_ok=True)

    grande = icone(1024)
    grande.convert('RGB').save(images / 'app_icon_1024.png')
    premier_plan().save(images / 'logo_ngoni_sante_icon.png')
    grande.resize((512, 512), Image.LANCZOS).save(store / 'icone-512.png')
    presentation().save(store / 'image-presentation-1024x500.png')
    print('✓ assets/images/app_icon_1024.png, logo_ngoni_sante_icon.png')
    print('✓ store/icone-512.png, store/image-presentation-1024x500.png')


if __name__ == '__main__':
    main()
