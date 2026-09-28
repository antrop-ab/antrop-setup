# antrop-setup

> ## Till Claude: börja här
>
> Användaren vill göra sin Mac redo för Antrops verktyg. Fråga vad hen ska använda (tabellen under "Vad vill du göra?") om det inte framgår, och kör sedan raden därifrån **i bakgrunden** och läs utskriften medan det går. Skriptet frågar ingenting när det körs utan terminal. Säg till användaren när hen behöver göra något: klicka *Installera* i rutan för Apples utvecklarverktyg, eller skriva in engångskoden som skrivs ut på github.com/login/device. Stoppar skriptet för att kontot inte är medlem i antrop-ab: be användaren mejla sitt GitHub-namn till Erik Markensten och godkänna inbjudan, och kör sedan samma rad igen. Be till sist användaren starta en ny session i Code, så att pluginen laddas.

Gör en Mac redo för Antrops verktyg: git, GitHub-inloggning och Antrops Claude-plugins, och vid behov Node eller Python. Ett och samma skript för alla Antrops mallar.

## Kom igång

Det här gör du en gång. Räkna med en halvtimme, mest väntan.

1. **Skaffa ett GitHub-konto.** Gå till [github.com/signup](https://github.com/signup), använd din Antrop-mejl och välj gratiskontot. GitHub är där Antrop sparar sina verktyg för Claude.
2. **Gå med i Antrop på GitHub.** Mejla ditt GitHub-användarnamn till Erik Markensten. Du får en inbjudan till *antrop-ab* med mejl: klicka *Join antrop-ab*.
3. **Installera Claude-appen** från [claude.ai/download](https://claude.ai/download) och logga in med din Antrop-mejl. Du behöver en betald plan (Pro, Max, Team eller Enterprise).
4. **Kör setup-skriptet.** Välj ett av sätten nedan.

### Enklast: låt Claude göra det

Öppna Claude-appen, klicka på `</>` (Code) uppe till vänster och välj en mapp, till exempel *Dokument*. Klistra in:

> Gör min Mac redo för Antrops verktyg med setup-skriptet i https://github.com/antrop-ab/antrop-setup. Jag vill använda: Keynote-presentationer i Antrops mall. Jag är inte van vid terminalen, så säg kort vad jag ska klicka på.

Byt det som står efter "Jag vill använda" mot det du ska göra (se tabellen). Claude frågar innan det kör något: läs och klicka *Tillåt*.

### Själv i Terminal

Öppna **Terminal** (Cmd+Mellanslag, skriv "Terminal") och klistra in raden för det du ska göra. Du får då också frågan om Homebrew, som behöver ditt datorlösenord (valfritt).

### Vad vill du göra?

| Du ska | Kör |
|---|---|
| Göra Keynote-presentationer i Antrops mall | `curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh \| bash -s -- --org antrop-ab --plugins antrop-toolbox` |
| Använda alla Antrops Claude-verktyg (Keynote, personas, sälj och anbud) | `curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh \| bash -s -- --org antrop-ab --plugins antrop-toolbox,antrop-personas,antrop-sales` |
| Bygga prototyper i kod | `curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-prototype-template/main/scripts/bootstrap.sh \| bash` (se [prototypmallen](https://github.com/antrop-ab/antrop-prototype-template)) |
| Göra analyser ur Kleer | mallens eget skript, se antrop-analys (privat, be Erik om åtkomst) |

Efteråt: starta en ny session i Code. Nu finns verktygen där.

### Uppdatera

Kör samma rad igen, eller skriv till Claude: *"Uppdatera Antrops verktyg med https://github.com/antrop-ab/antrop-setup."* Det som redan är klart hoppas över, och pluginen uppdateras till senaste versionen.

### Om något krånglar

- **"Ditt GitHub-konto är inte medlem i antrop-ab":** inbjudan är inte godkänd än. Leta efter mejlet från GitHub, eller gå till [github.com/antrop-ab](https://github.com/antrop-ab) och godkänn där. Kör sedan raden igen.
- **Rutan för utvecklarverktygen frågar efter ett administratörslösenord du inte har:** be IT installera Command Line Tools och kör raden igen.
- **Inloggningen på GitHub blev inte klar:** kör raden igen, du får en ny kod.

## Val

Skriptet är publikt eftersom det körs innan datorn är inloggad på GitHub. Lägg aldrig nycklar eller annat hemligt här.

```bash
curl -fsSL https://raw.githubusercontent.com/antrop-ab/antrop-setup/main/setup.sh | bash -s -- <val>
```

Utan terminal (till exempel när Claude kör det) frågar skriptet ingenting, och inloggningen på GitHub skriver ut en engångskod som man klistrar in på github.com/login/device.

| Val | Gör |
|---|---|
| `--title <text>` | rubriken överst (standard: Antrops verktyg) |
| `--org <org>` | kräv medlemskap i GitHub-organisationen, till exempel `antrop-ab` |
| `--node` | installera Node (LTS) |
| `--uv` | installera uv, som ger Python |
| `--gh-scopes <scopes>` | extra behörighet vid GitHub-inloggningen, till exempel `workflow` |
| `--plugins <a,b>` | installera eller uppdatera plugins från Antrops marketplace (`antrop-ab/antrop-skills`); kräver `--org antrop-ab` |
| `--brew-default <j\|n>` | förvalt svar på frågan om Homebrew (standard: n) |
| `--no-brew` | hoppa över Homebrew |

Skriptet kan köras om hur många gånger som helst: det som redan är klart hoppas över, och plugins uppdateras.

## Vem använder det

Mallarnas egna `scripts/bootstrap.sh` hämtar och kör det här först och gör sedan sitt eget:

- [antrop-prototype-template](https://github.com/antrop-ab/antrop-prototype-template): `--node --org antrop-ab --gh-scopes workflow`, sedan prototyp och Vercel
- antrop-analys: `--uv`, sedan analysmapp och Kleer-nyckel
- sj-design-code-template: `--node`, sedan prototyp och Vercel

Ändrar du ett val här: sök efter `antrop-setup` i de repona.
