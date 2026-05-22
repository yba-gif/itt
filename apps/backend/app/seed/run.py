"""Idempotent seed runner — kantons, categories, content pages, admin user.

Run via: ``python -m app.seed.run`` (auto-invoked by docker-compose backend command).
"""

from __future__ import annotations

import asyncio
from uuid import uuid4

from sqlalchemy import select

from app.config import settings
from app.db import SessionLocal
from app.models.category import Category
from app.models.content_page import ContentPage
from app.models.kanton import Kanton
from app.models.user import User
from app.seed.categories import CATEGORIES
from app.seed.kantons import KANTONS
from app.services.auth import hash_password


async def seed_kantons(session) -> None:
    existing = (await session.execute(select(Kanton.code))).scalars().all()
    have = set(existing)
    for code, tr, de in KANTONS:
        if code in have:
            continue
        session.add(Kanton(code=code, name_tr=tr, name_de=de))


async def seed_categories(session) -> None:
    existing = (
        await session.execute(select(Category.directory, Category.name_tr))
    ).all()
    have = {(d, n) for d, n in existing}
    for directory, names in CATEGORIES.items():
        for name in names:
            if (directory, name) in have:
                continue
            session.add(Category(id=uuid4(), directory=directory, name_tr=name))


async def seed_content_pages(session) -> None:
    pages = [
        ("welcome", "Hoş Geldiniz",
         "İsviçre'ye hoş geldiniz! Bu rehberin Faz 2'de tamamlanacak içeriği yakında burada olacak."),
        ("emergency", "Acil Durumlar",
         "- Polis: 117\n- İtfaiye: 118\n- Tıbbi Acil: 144\n- Zehir Danışma: 145\n- Yol Yardım: 140"),
        ("consulate", "Türk Konsolosluğu Bilgileri",
         "Bern Büyükelçiliği ve Zürih Başkonsolosluğu bilgileri Faz 2'de eklenecek."),
        ("privacy", "Gizlilik Politikası", "Gizlilik politikası taslağı — yayın öncesi güncellenecek."),
        ("terms", "Kullanım Koşulları", "Kullanım koşulları taslağı — yayın öncesi güncellenecek."),
        ("about", "Hakkımızda",
         "## İsviçre Türk Toplumu\n\n"
         "İsviçre Türk Toplumu (İTT, Almanca: Türkische Gemeinschaften Schweiz, TGS), "
         "İsviçre'deki çoğu Türk Dernek ve Federasyonunun çatı kuruluşudur. Bağımsız bir "
         "STK (Sivil Toplum Kuruluşu) olarak kurulmuştur. Faaliyetleri İsviçre Medeni "
         "Kanununa (ZGB Madde 60 ff) dayanmaktadır.\n\n"
         "## İsviçre'deki Türklerin Durumu\n\n"
         "Bugün İsviçre'de yaklaşık 130.000 Türk kökenli insan yaşıyor ve bunların "
         "40.000'den fazlası İsviçre vatandaşıdır. Türkler 1960'ların başından bu yana "
         "eğitim veya iş için İsviçre'ye göç etmişlerdir. Birinci nesil artık emeklilik "
         "yaşındadır. Bunlardan temelli dönüş yapanların yanı sıra İsviçre'de yaşamayı "
         "tercih edenler veya her iki ülkede de yaşamayı tercih edenler vardır.\n\n"
         "İTT'nin amacı, öncelikle ikinci ve üçüncü kuşağın endişeleri ve sorunlarıyla "
         "ilgilenmek ve çoğunluğu İsviçre'de kalacağı için onları İsviçre toplumuyla "
         "bütünleşmelerinde desteklemektir.\n\n"
         "Entegrasyonu kolaylaştırmak için İsviçreli kuruluşlar ve yetkililer, "
         "İsviçre'de uyum içerisinde bir arada yaşama için ortak çözümler bulmak amacıyla "
         "farklı etnik grupların endişelerini, ihtiyaçlarını ve sorunlarını daha iyi "
         "anlamak istiyor. İTT, Türk toplumunun çeşitli sorunları ve entegrasyonunun nasıl "
         "ele alınacağını iyi bildiği için ilgili İsviçre kurumlarının bir ortağı olarak "
         "kendisini görmektedir.\n\n"
         "## İTT'nin Hedefleri\n\n"
         "İTT'nin amacı, İsviçre'deki Türklerin sorunlarını ve ihtiyaçlarını tespit etmek "
         "ve onlarla ve İsviçre kuruluşlarıyla birlikte çözüm konseptleri geliştirmek, "
         "ikinci ve üçüncü nesil eğitimin iyileştirilmesine ve eğitim seviyesinin "
         "yükseltilmesine katkıda bulunmaktır.\n\n"
         "Her iki toplum arasında güçlü işbirlikleri oluşturmak için Türk toplumu ile "
         "İsviçre toplumu arasındaki iletişim ve kültürel alışveriş daha da "
         "geliştirilmelidir. Türk vatandaşlarının İsviçre toplumuna entegrasyonu, bununla "
         "birlikte her iki toplumun ortak kurallara (haklar ve sorumluluklar) ve karşılıklı "
         "saygı çerçevesinde uyumlu bir şekilde bir arada yaşaması da İsviçre'deki Türk "
         "toplumunun hedeflerinden biridir.\n\n"
         "İTT'nin bir diğer amacı da eğitim, yetiştirme, uyum ve kültür gibi genel "
         "konularda Türkleri İsviçre ve Türk makamları ve kuruluşları nezdinde temsil "
         "etmektir.\n\n"
         "Bu hedeflere ulaşabilmek için İTT bünyesinde çeşitli çalışma komisyonları "
         "oluşturulmuştur."),
    ]
    existing = set((await session.execute(select(ContentPage.slug))).scalars().all())
    for slug, title, body in pages:
        if slug in existing:
            continue
        session.add(ContentPage(slug=slug, title=title, body_markdown=body))


async def seed_admin(session) -> None:
    email = settings.admin_seed_email
    user = (
        await session.execute(select(User).where(User.email == email))
    ).scalar_one_or_none()
    if user is not None:
        if not user.is_admin:
            user.is_admin = True
        return
    session.add(
        User(
            email=email,
            password_hash=hash_password(settings.admin_seed_password),
            display_name="Admin",
            is_admin=True,
        )
    )


async def main() -> None:
    async with SessionLocal() as session:
        await seed_kantons(session)
        await seed_categories(session)
        await seed_content_pages(session)
        await seed_admin(session)
        await session.commit()
    print("seed: ok")


if __name__ == "__main__":
    asyncio.run(main())
