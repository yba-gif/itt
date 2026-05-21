#!/usr/bin/env python3
"""
Download all v1 images to seeds/images/ for migration to Cloudflare R2.
Run: python3 seeds/download_images.py
Then upload: for f in seeds/images/*; do wrangler r2 object put itt-media/listings/$(basename $f) --file=$f; done
"""
import urllib.request, os, re, json, sys

IMAGES = [
  {
    "id": "6f52babd-243f-51b5-8a49-dbea8d5da85f",
    "name": "Belinda Nazan Walpoth",
    "url": "https://lh3.googleusercontent.com/d/1aMm5sskDPcQ7yDu5uf1EjbR25DGRFrNI"
  },
  {
    "id": "3665fdbf-4ca8-5e55-bcb7-dc876733a3b2",
    "name": "Bülent Konuk",
    "url": "https://lh3.googleusercontent.com/d/1w3sjRnjUoxDumhrIFtNniYGpfcBFhGoS"
  },
  {
    "id": "4f044e33-4475-563e-afe7-5b1f5dc7afd4",
    "name": "Çağdaş Kaya",
    "url": "https://lh3.googleusercontent.com/d/13LWuQfN_Yie9dtPNmy0JYaX4cBbz1KKS"
  },
  {
    "id": "b06da8df-bb08-5e00-be5b-0b31d1e19028",
    "name": "Çiğdem Kaya",
    "url": "https://lh3.googleusercontent.com/d/1VOud-mflA9rHkgR_hJru56wTziw-nBx7"
  },
  {
    "id": "738e86b6-8036-5a18-98c8-6c4eef374a50",
    "name": "Dr. med. Gazi Keskin",
    "url": "https://lh3.googleusercontent.com/d/1tJA9Q5NnQFXTfrRGbitLGXKpjYI_SV-O"
  },
  {
    "id": "bdb4e30e-fe94-5136-8649-752432350102",
    "name": "Edib Ademi",
    "url": "https://lh3.googleusercontent.com/d/1KCWBtgXMPEL7VYaiDcGyIvQij-Wqkldg"
  },
  {
    "id": "2b9daf39-d2b6-5f35-bd36-d6a94ae46325",
    "name": "Esat Mahmut Özşahin (Prof.)",
    "url": "https://lh3.googleusercontent.com/d/1KFjftDEhh2DDtyYetHHOB8i5lk2ApeuB"
  },
  {
    "id": "81eb3c25-37cb-5409-ad11-e98f32ddc808",
    "name": "Fırat Elmas",
    "url": "https://lh3.googleusercontent.com/d/1h6ZPDux90HrCbI0JfXE9k5ycLy3X1USI"
  },
  {
    "id": "390edc96-16bd-51df-aa8e-bb8652feab46",
    "name": "Gönül Korkmaz Kaya",
    "url": "https://lh3.googleusercontent.com/d/17SurgL-Q6X6vX84hPuHeW7OMmlIgKXb8"
  },
  {
    "id": "d4134e3d-a687-5a58-b339-2088b0e0e9d5",
    "name": "Gülhan Calik Yarici",
    "url": "https://lh3.googleusercontent.com/d/159iKFEf-4N4lS5thd_2u9EDdickqdzjh"
  },
  {
    "id": "77571786-661e-5210-8685-8ec9715e5ff8",
    "name": "Gülseven Gül",
    "url": "https://lh3.googleusercontent.com/d/1zfoPb9FVyhpzYwlO9TAGkjr_l-pwh6ru"
  },
  {
    "id": "f41a97de-600c-5be0-bbff-0d98feb4f901",
    "name": "İhsan İnan",
    "url": "https://lh3.googleusercontent.com/d/16lPia__QJOo1newGOKy807WeMCeOR0zm"
  },
  {
    "id": "2fe204e5-1e75-532a-8daa-9458aa0d39f5",
    "name": "İkbale Siercks",
    "url": "https://lh3.googleusercontent.com/d/17nDLqN3qGme6AE5dx3jfhuIQ8THUMonk"
  },
  {
    "id": "dac2ec15-017e-5ece-8bcf-fc372917a851",
    "name": "Kadir Oktay Kocagöncü",
    "url": "https://lh3.googleusercontent.com/d/1CiqSxN5v3P-1vp39DpuPbKE00Qg9TAUV"
  },
  {
    "id": "13fc5333-72b2-5ee9-b6c0-509170cb7b14",
    "name": "Kemal Budak",
    "url": "https://lh3.googleusercontent.com/d/1V_Ss8iWQY6WjMvC2jmdd9HAZNC7tmos3"
  },
  {
    "id": "bbc31372-1319-54f5-8a61-eb9e030fdd11",
    "name": "Mehtap Tatan de Froment",
    "url": "https://www.doktor.ch/pictures/118755/portrait/118755.png"
  },
  {
    "id": "46a04e2a-a2c7-5c68-8aa1-d023f087db61",
    "name": "Murat Alan",
    "url": "https://lh3.googleusercontent.com/d/19p4TqAHBfFKrmDBIX-3DslV37uLtOZM5"
  },
  {
    "id": "ec828ef7-8b21-55d0-8f7e-6ffd02bbaa64",
    "name": "Orhan Özsoy",
    "url": "https://lh3.googleusercontent.com/d/1sixJLWbOigvvfIgFKMpxixVLRj5r0lwT"
  },
  {
    "id": "2d705c3b-758e-512a-80fa-01bf74871b7c",
    "name": "Teslim Fidanoğlu",
    "url": "https://d2f0ora2gkri0g.cloudfront.net/8c/\n33/8c3315a3-9ef2-45dd-b624-2a957f7\n5bf3d.jpg"
  },
  {
    "id": "ac8ebe04-2968-58cb-b7a0-6398e0e1d7fd",
    "name": "Yakup Yakupoğlu",
    "url": "https://lh3.googleusercontent.com/d/1G2a0jjlPTgoSkscLn5Yxk2Gy5ukWdxzd"
  },
  {
    "id": "a037ca32-360d-5e3c-a248-5029740bae64",
    "name": "Zöhre Akdoğan",
    "url": "https://lh3.googleusercontent.com/d/1UxahIhHe6KKDmVlyLiPjnWo5poHEuYyV"
  },
  {
    "id": "25082c8d-c099-595f-b4d6-0520cce50e38",
    "name": "Cennet Sönmez",
    "url": "https://cennet-consulting.ch/assets/images/logo.png"
  },
  {
    "id": "2d8317e8-9db8-5945-b5e9-d9cafa4079c0",
    "name": ".İsviçre Türk Toplumu İTT",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "95fcc480-9bd9-537d-acc9-47998c383151",
    "name": "Berin Kısıkyol",
    "url": "https://lh3.googleusercontent.com/d/1QLVtskwpjqKyDjXCFrl5cOzH1zmD6RkN"
  },
  {
    "id": "e431d6ed-48e8-55ee-9c1e-eab28b5f8ded",
    "name": "Gamze Arslan Tonus",
    "url": "https://lh3.googleusercontent.com/d/1s12031Iqk9DXKJ2b7rTNiAT8K_FUAz4g"
  },
  {
    "id": "e1faba5d-dad5-5e11-becf-0e6dec54f237",
    "name": "Miran Sarı",
    "url": "https://lh3.googleusercontent.com/d/1TICCJl_mkOdxsc3e16UVFClGfgppN4E0"
  },
  {
    "id": "ef44693b-39cf-569f-8174-655cb2ce2941",
    "name": "Mustafa Bayrak",
    "url": "https://legalpartners.ch/wp-content/uploads/2023/03/mustafa-bayrak-anwalt-legal-partner-zuerich-01-3.jpg"
  },
  {
    "id": "9bfda96f-b109-5705-bc04-52204ffe6aca",
    "name": "4D Montagen GmbH",
    "url": "https://lh3.googleusercontent.com/d/1W8zO8L1C2ci6pI9ykRlR7RM6V6M6zDXc"
  },
  {
    "id": "546ac84d-930e-59d1-a337-882274aa32ce",
    "name": "Adam's Döner",
    "url": "https://lh3.googleusercontent.com/d/1QkjmWE6eddRdxSTodfdrAeIvb_G6GQGu"
  },
  {
    "id": "046d4518-eabb-5df7-8a23-85b87aae18a6",
    "name": "Akın Logistik",
    "url": "https://lh3.googleusercontent.com/d/1QoL80xpTXElYprVIHggKZJMbyqXCVcNL"
  },
  {
    "id": "90730736-363f-5ef6-86a3-c450864023e1",
    "name": "Aksa Food",
    "url": "https://lh3.googleusercontent.com/d/1aORH6Q_zKeZTTSzvH5DKRxlBi1QL9paF"
  },
  {
    "id": "c0a225b7-c97e-54f9-851a-5d45eaa8ebd3",
    "name": "Altay Travel",
    "url": "https://lh3.googleusercontent.com/d/1b-4spMfDS9VNvZcAAF4vy7vxq5KRyEmb"
  },
  {
    "id": "2978792d-3cf8-5ec6-9d08-09d0d32deb9e",
    "name": "Altın Steakhouse",
    "url": "https://zurich.altin-steakhouse.ch/wp-content/uploads/2024/02/zurich.png"
  },
  {
    "id": "cb298777-b628-58f8-82ff-f767d3bb75c6",
    "name": "Altın Steakhouse",
    "url": "https://aarburg.altin-steakhouse.ch/wp-content/uploads/2024/02/aarburg.png"
  },
  {
    "id": "d5741abb-b24a-58c1-aca2-3d08aff08aec",
    "name": "AYDINS",
    "url": "https://lh3.googleusercontent.com/d/1UdxkcNZ634a1LsdrbRQxnydkRNs1O0RW"
  },
  {
    "id": "da6a8231-6f3d-5353-84d6-3c110c689558",
    "name": "Berem",
    "url": "https://lh3.googleusercontent.com/d/1nQXd2UBtL-ERLxveY5DqtKzOjeDOdKrK"
  },
  {
    "id": "df4266fc-2277-5022-a521-fe93be036413",
    "name": "Can Grill Haus",
    "url": "https://lh3.googleusercontent.com/d/10-Pa83Q4iDLt4PJhnawD4Iuf2WVAQX1t"
  },
  {
    "id": "6c141b27-64fd-56a9-82a1-5dc4e29eb837",
    "name": "Coral Travel",
    "url": "https://lh3.googleusercontent.com/d/1nR5WmLwYycJL28lNwq6U1Nw8pDAZBuSP"
  },
  {
    "id": "2cffb1b9-ee77-5bea-9c1a-c835b915a32e",
    "name": "Dägerli Schönegg Garage GmbH",
    "url": "https://lh3.googleusercontent.com/d/1ogW0Ks4eksP2li6Xu2c1iHu5P0Y1EzCt"
  },
  {
    "id": "9cfa09fc-0058-5fa9-b7d3-3626146e2654",
    "name": "DAIMEX AG",
    "url": "https://lh3.googleusercontent.com/d/1nTMsuJXYKVccxPtMDT8Srj_hgsQMaagW"
  },
  {
    "id": "27df4d6d-72ca-5897-8e3a-9d0130187041",
    "name": "Enderli Metallbau AG",
    "url": "https://lh3.googleusercontent.com/d/1f9dMLZTPYQu7OCgR153bn29PgEoMOlat"
  },
  {
    "id": "0c4173aa-6f37-53e8-9e8d-64854543c54c",
    "name": "ePowerCon AG",
    "url": "https://lh3.googleusercontent.com/d/1fv2Uxj_nIarmFXQAOOi0mUuy7UzOFCGr"
  },
  {
    "id": "8b83bbba-01a5-5579-80a8-c61c94034f4d",
    "name": "Garage Ulus",
    "url": "https://lh3.googleusercontent.com/d/1YzaoEVkKkYHg01l4LAam5UdYl9BB7rSI"
  },
  {
    "id": "37af6a72-7469-557f-89bc-81d6164949fb",
    "name": "Güneş Grenchen",
    "url": "https://lh3.googleusercontent.com/d/18BemSTpPZw-J930pZyvC4o-1bE_rMuVG"
  },
  {
    "id": "21cae1db-1333-5d2a-88b3-bb4e30bef9a7",
    "name": "Güneş Hägendorf",
    "url": "https://lh3.googleusercontent.com/d/1OjvcauHuNqSHihWvNpor38Ax2bIGEFyV"
  },
  {
    "id": "247f311c-ae17-54b5-8cc9-6d6b343b7076",
    "name": "Gurbet Döner",
    "url": "https://xn--gurbet-dner-yfb.ch/wp-content/uploads/2022/12/logo-1536x554.png"
  },
  {
    "id": "5716fa04-2583-516c-9222-0a0bbd7d9f23",
    "name": "Gurbet Market",
    "url": "https://lh3.googleusercontent.com/d/1x5NShc52q_pN--AhcLvuJAKm-pln9E5P"
  },
  {
    "id": "20ae9ee3-e76c-5094-b230-61cd89a059bd",
    "name": "Gurbet Market",
    "url": "https://lh3.googleusercontent.com/d/1x5NShc52q_pN--AhcLvuJAKm-pln9E5P"
  },
  {
    "id": "221a45d1-0a3d-5397-be49-8d0f6d3f3497",
    "name": "Güven Shop",
    "url": "https://lh3.googleusercontent.com/d/16lmU9mFrJH7m6MUEraDypK40QlkWLbvV"
  },
  {
    "id": "3c5510c6-bc2e-5c3b-9390-d994feac681a",
    "name": "Hair & Beauty Beyza",
    "url": "https://lh3.googleusercontent.com/d/1D6BCPmxbYk6PQYk9LBOGwHsPxcpNsEHq"
  },
  {
    "id": "4e6f9555-6fb5-5eac-839b-61960a4ab6b4",
    "name": "HAN Teppichreinigung",
    "url": "https://lh3.googleusercontent.com/d/1gKpxGceh6Zwhy4AAJkmW9Ke5iu0zv9t5"
  },
  {
    "id": "4defaae5-a693-5bde-8ffb-fd716077e2f8",
    "name": "Has Gastro Service AG",
    "url": "https://lh3.googleusercontent.com/d/1k7zshfpr8w1GeJOBvuj0J-B9UIOBKzDF"
  },
  {
    "id": "87c8d6ba-ec01-568f-9521-4dff1cdec870",
    "name": "Memet Usta Restaurant & Grill",
    "url": "https://lh3.googleusercontent.com/d/1lyrm8V2XVijUXD3xPTuxHW_63_y-LE-R"
  },
  {
    "id": "5650baf1-ec04-564a-bf65-5a7c2b6d6605",
    "name": "Möbelwelt - İstikbal - Bellona",
    "url": "https://lh3.googleusercontent.com/d/1wfpYPNdO4fLhyS5df2jBUs-SX2QFzItl"
  },
  {
    "id": "39904352-606e-5ae4-bb02-592645bd51ae",
    "name": "Mus-Et Steakhouse",
    "url": "https://lh3.googleusercontent.com/d/1DbLSbdFqfdf_WpSVX1N0nwE2EiwgnF9t"
  },
  {
    "id": "3b2c7574-454c-5be7-b755-98b4027587a5",
    "name": "Netto",
    "url": "https://www.nettoschlieren.ch/wp-content/uploads/2018/04/netto-schlieren-logo-500.png"
  },
  {
    "id": "6a835049-9e90-5f70-a615-096e05333626",
    "name": "Pala-Food GmbH",
    "url": "https://lh3.googleusercontent.com/d/1cTFGA39M888NyASU4U_n4isAoiRjBEkq"
  },
  {
    "id": "383fc1e7-5976-5466-8d9e-d3a7e04be82c",
    "name": "Planet Consulting",
    "url": "https://lh3.googleusercontent.com/d/1DriOhgT1aKcFhyaePoMzIXzoaetddgaA"
  },
  {
    "id": "d7f6c5f8-1b89-5940-8a6f-cc11d9e22a76",
    "name": "RE/MAX Cihan Salda",
    "url": "https://lh3.googleusercontent.com/d/1r_LeTx5zzfBp5WfVlKPYHHebHrwIamh4"
  },
  {
    "id": "f209c8c8-b835-52b0-a49e-834ed4b33d2a",
    "name": "Serkan Coiffeur",
    "url": "https://lh3.googleusercontent.com/d/1n68ytUw7iJgf-WD6TOqnq6NhDlXPaOvC"
  },
  {
    "id": "a0fdda75-ae4e-5da5-8dc8-48aac55eb813",
    "name": "Wengi's Steakhouse",
    "url": "https://lh3.googleusercontent.com/d/1bi53veVavwZTeP3MuZkYEWNoidvrYzsG"
  },
  {
    "id": "70acf054-0308-5dc4-828e-7bcd30ffffea",
    "name": "yalcom GmbH",
    "url": "https://lh3.googleusercontent.com/d/1VCzyaM4UL3RJt1idlgb5ms0Q_MRmGaGZ"
  },
  {
    "id": "0fb2d724-35d6-561a-b697-16d420bc338d",
    "name": "İşletme1",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "5e3cce2b-7fc2-50c7-a5f6-a1d0cbdea7f4",
    "name": "deneme",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "6d794523-cd14-5bdb-8520-6d414c5bde64",
    "name": "İsviçre Türk Toplumu İTT",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "c3437311-b8b5-5118-a946-85f251e958a7",
    "name": "Baris Kredit",
    "url": "https://lh3.googleusercontent.com/d/1erTPtTka0TfkfnsonRUW_3so_qSafk9Q"
  },
  {
    "id": "385fdf42-2f2a-5bc0-bb41-870781cf2ebd",
    "name": "Baris Kredit",
    "url": "https://lh3.googleusercontent.com/d/1B7vjNTpJGtI8aEcWN06HcNaep7Ugjslo"
  },
  {
    "id": "8f554339-4f15-5c8c-871d-987af885c23b",
    "name": "Cennet Sönmez",
    "url": "https://cennet-consulting.ch/assets/images/logo.png"
  },
  {
    "id": "c312c0a8-30d3-528c-9519-5edad6e8339a",
    "name": "Teslim Fidanoğlu",
    "url": "https://d2f0ora2gkri0g.cloudfront.net/8c/\n33/8c3315a3-9ef2-45dd-b624-2a957f7\n5bf3d.jpg"
  },
  {
    "id": "62aae99c-f571-5e11-a99f-1a662e2f57b2",
    "name": "Mehtap Tatan de Froment",
    "url": "https://www.doktor.ch/pictures/118755/portrait/118755.png"
  },
  {
    "id": "ac2ad0a3-e4cd-5b2b-bfc0-4decfbd3119b",
    "name": ".İsviçre Türk Toplumu İTT",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "7c186c1c-47c8-5926-809e-63d2fa57f632",
    "name": "Fatih Karaoğlu",
    "url": "https://lh3.googleusercontent.com/d/1n9v0WtoB6GeJOuxsatrdd0tp8IiO8uqO"
  },
  {
    "id": "2ea30be6-3cfb-563b-a0a3-8b7530fc200c",
    "name": "İsviçre Türk Toplumu İTT",
    "url": "https://tgs-itt.ch/wp-content/uploads/2022/01/cropped-oynanmis.png"
  },
  {
    "id": "f499c635-b7d0-5601-8666-55a7851ce839",
    "name": "Halal Food Festival",
    "url": "https://lh3.googleusercontent.com/d/1JTae1agSf6nDiABHNvZnbPQAjXL0-8P2"
  },
  {
    "id": "97694888-7900-5106-87c5-e589b33a0f5a",
    "name": "Halal Food Festival",
    "url": "https://lh3.googleusercontent.com/d/1skVPu3CcCtxnyXvzFlZhglkcZqd1K6vg"
  },
  {
    "id": "d08cb66a-3957-5e32-aca4-3d1719ca72ee",
    "name": "Türk Kültür Festivali",
    "url": "https://lh3.googleusercontent.com/d/1IG8j3xipkWgsHU6pqOWzvAST7S13MtdX"
  },
  {
    "id": "bf78dd49-ede9-5109-b82f-c21e60490019",
    "name": "Türk Kültür Festivali",
    "url": "https://lh3.googleusercontent.com/d/1IG8j3xipkWgsHU6pqOWzvAST7S13MtdX"
  }
]

OUT_DIR = os.path.join(os.path.dirname(__file__), 'images')
os.makedirs(OUT_DIR, exist_ok=True)

for img in IMAGES:
    uid  = img['id']
    url  = img['url']
    ext  = re.search(r'\.(jpg|jpeg|png|gif|webp)', url.lower())
    ext  = ext.group(0) if ext else '.jpg'
    dest = os.path.join(OUT_DIR, uid + ext)
    if os.path.exists(dest):
        print(f"  ✓ skip {uid}{ext}")
        continue
    try:
        print(f"  ↓ {img['name'][:40]}")
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15) as r, open(dest, 'wb') as f:
            f.write(r.read())
    except Exception as e:
        print(f"  ✗ FAILED {url[:60]} — {e}", file=sys.stderr)

print(f"\nDone. Check seeds/images/ ({len(os.listdir(OUT_DIR))} files)")
