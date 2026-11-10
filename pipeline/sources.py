"""Registry of every source: where it comes from, its licence, its credit, and whether it may enter the default bundle.

licence_class values and the default bundle gate:
  PD, CC0, UNLICENSE, CC-BY-4.0, CC-BY-SA-4.0   allowed in the default build
  US-ONLY-PD, GPL-3.0                           personal build only (--personal)
  NC                                            personal build only, and not implemented here
"""
DEFAULT_OK = {"PD", "CC0", "UNLICENSE", "CC-BY-4.0", "CC-BY-SA-4.0"}
PERSONAL_OK = DEFAULT_OK | {"US-ONLY-PD", "GPL-3.0"}

CC_BY = "https://creativecommons.org/licenses/by/4.0/"
CC_BY_SA = "https://creativecommons.org/licenses/by-sa/4.0/"
STEP_CREDIT = 'Data from STEP Bible (www.STEPBible.org), created by Tyndale House Cambridge, licensed CC BY 4.0. Changes made in this app are recorded in the pipeline source.'

SOURCES = {
 "step-tahot": dict(name="STEP Bible TAHOT, Translators Amalgamated Hebrew OT", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/STEPBible/STEPBible-Data/tree/master/Translators%20Amalgamated%20OT%2BNT", credit=STEP_CREDIT,
    licence_quote='This public licence allows you to: Include any part of STEPBible-Data in any software or publications without requesting permission'),
 "step-tagnt": dict(name="STEP Bible TAGNT, Translators Amalgamated Greek NT", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/STEPBible/STEPBible-Data/tree/master/Translators%20Amalgamated%20OT%2BNT", credit=STEP_CREDIT, licence_quote=""),
 "step-tbesh": dict(name="STEP Bible TBESH, Translators Brief lexicon of Extended Strongs for Hebrew", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/STEPBible/STEPBible-Data/tree/master/Lexicons", credit=STEP_CREDIT, licence_quote=""),
 "step-tbesg": dict(name="STEP Bible TBESG, Translators Brief lexicon of Extended Strongs for Greek", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/STEPBible/STEPBible-Data/tree/master/Lexicons", credit=STEP_CREDIT, licence_quote=""),
 "step-tvtms": dict(name="STEP Bible TVTMS, Translators Versification Traditions", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/STEPBible/STEPBible-Data/tree/master/Versification", credit=STEP_CREDIT, licence_quote=""),
 "oshb-wlc": dict(name="Open Scriptures Hebrew Bible (Westminster Leningrad Codex), used for expected Hebrew verse counts", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://github.com/openscriptures/morphhb", credit='Original work of the Open Scriptures Hebrew Bible available at https://github.com/openscriptures/morphhb',
    licence_quote='This work is based on The Westminster Leningrad Codex, which is in the public domain.'),
 "os-strongs-heb": dict(name="Strong's Hebrew Dictionary (Open Scriptures XML)", licence_class="PD", licence_url="https://github.com/openscriptures/strongs",
    url="https://github.com/openscriptures/strongs/tree/master/hebrew", credit="James Strong, 1894. XML by Open Scriptures. TWOT references removed.", licence_quote="<rights>Public Domain</rights>"),
 "os-strongs-grk": dict(name="Strong's Greek Dictionary (Open Scriptures XML 1.4)", licence_class="PD", licence_url="https://github.com/openscriptures/strongs",
    url="https://github.com/openscriptures/strongs/tree/master/greek", credit="James Strong, 1894. XML by Open Scriptures.", licence_quote="Public Domain -- Copy Freely"),
 "openbible-xref": dict(name="OpenBible.info Cross References", licence_class="CC-BY-4.0", licence_url=CC_BY,
    url="https://www.openbible.info/labs/cross-references/", credit="Cross references from OpenBible.info, licensed CC BY 4.0, drawn mainly from the Treasury of Scripture Knowledge.",
    licence_quote="Unless otherwise indicated, all content is licensed under a Creative Commons Attribution License"),
 "sblgnt": dict(name="SBL Greek New Testament", licence_class="CC-BY-4.0", licence_url=CC_BY, url="https://github.com/Faithlife/SBLGNT",
    credit="Scripture quotations marked SBLGNT are from the SBL Greek New Testament. Copyright 2010 by the Society of Biblical Literature and Logos Bible Software. Licensed CC BY 4.0.",
    licence_quote="The SBLGNT is licensed under a Creative Commons Attribution 4.0 International License."),
 "byz-rp2018": dict(name="Robinson Pierpont Byzantine Majority Text 2018", licence_class="UNLICENSE", licence_url="https://unlicense.org",
    url="https://github.com/byztxt/byzantine-majority-text", credit="Maurice A. Robinson and William G. Pierpont, The New Testament in the Original Greek: Byzantine Textform 2018.",
    licence_quote="This is free and unencumbered software released into the public domain."),
 "nestle1904": dict(name="Nestle 1904 Greek New Testament with morphology", licence_class="CC0", licence_url="https://creativecommons.org/publicdomain/zero/1.0/",
    url="https://github.com/biblicalhumanities/Nestle1904", credit="Eberhard Nestle 1904 text (public domain), base text by Diego Renato dos Santos; morphology, lemmas and Strong's by Ulrik Sandborg-Petersen, CC0, biblicalhumanities.org.",
    licence_quote="biblicalhumanities.org has waived all copyright and related or neighboring rights to the biblicalhumanities.org Nestle 1904 Morphology."),
 "f1k-swete": dict(name="Swete, The Old Testament in Greek, First1KGreek TEI edition", licence_class="CC-BY-SA-4.0", licence_url=CC_BY_SA,
    url="https://github.com/OpenGreekAndLatin/First1KGreek/tree/master/data/tlg0527", credit="Henry Barclay Swete, The Old Testament in Greek according to the Septuagint (1909 to 1930). Digital text by the Open Greek and Latin First1KGreek project, CC BY SA 4.0; selected books corrected by the LXX-Swete project (github.com/sleeptillseven/LXX-Swete), CC BY SA 4.0. Our cleaned text is released under CC BY SA 4.0.",
    licence_quote="Available under a Creative Commons Attribution-ShareAlike 4.0 International License"),
 "swete-corrected": dict(name="LXX-Swete corrected books (sleeptillseven)", licence_class="CC-BY-SA-4.0", licence_url=CC_BY_SA,
    url="https://github.com/sleeptillseven/LXX-Swete", credit="Corrections by the LXX-Swete project, CC BY SA 4.0.", licence_quote="This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License"),
 "ebible-grcbrent": dict(name="Brenton Greek Septuagint (eBible.org grcbrent)", licence_class="PD", licence_url="https://ebible.org/grcbrent/copyright.htm",
    url="https://ebible.org/Scriptures/grcbrent_usfm.zip", credit="The Greek Septuagint with Apocrypha, compiled by Sir Lancelot C. L. Brenton, 1851. Public domain. Digital text courtesy of eBible.org.",
    licence_quote="Public Domain"),
 # personal build only
 "eliranwong-swete": dict(name="Swete LXX (eliranwong, GPL)", licence_class="GPL-3.0", licence_url="https://github.com/eliranwong/LXX-Swete-1930/blob/master/LICENSE",
    url="https://github.com/eliranwong/LXX-Swete-1930", credit="Swete text supplied by Pasquale Amicarelli; database by Eliran Wong, GPL v3.", licence_quote="GNU General Public License v3.0"),
}

# English public domain texts from eBible.org (id, name). engBBE is US only public domain.
EBIBLE_EN = [
 ("eng-asv","American Standard Version (1901)"),("engasvbt","American Standard Version Byzantine Text"),
 ("engBBE","Bible in Basic English"),("eng-Brenton","Brenton Septuagint Translation"),
 ("eng-uk-lxx2012","LXX2012: Septuagint in British/International English 2012"),("engDBY","Darby Translation"),
 ("engDRA","Douay-Rheims 1899"),("engbsb","Berean Standard Bible"),("enggnv","Geneva Bible 1599"),("engjps","JPS TaNaKH 1917"),
 ("eng-kjv2006","King James (Authorized) Version"),("eng-kjv","King James Version + Apocrypha"),("engkjvcpb","KJV Cambridge Paragraph Bible"),
 ("englee","Isaac Leeser Tanakh"),("eng-lxx2012","LXX2012: Septuagint in American English 2012"),("engmsb","Majority Standard Bible"),
 ("engmet","Masoretic English Tanakh"),("engnoy","George Noyes Bible"),("engoebcw","Open English Bible (Commonwealth Spelling)"),
 ("engoebus","Open English Bible (U. S. spelling)"),("eng-rv","Revised Version with Apocrypha (1895)"),("engoke","Targum Onkelos Etheridge"),
 ("engtnt","Tyndale New Testament"),("englxxup","Updated Brenton English Septuagint"),("engwebster","Noah Webster Bible"),
 ("engwebp","World English Bible"),("eng-web-c","World English Bible (Catholic)"),("engwebpb","World English Bible British Edition"),
 ("eng-webbe","World English Bible British Edition with Deuterocanon"),("eng-web","World English Bible Classic"),("engwebu","World English Bible Updated"),
 ("engwmb","World Messianic Bible"),("engwmbb","World Messianic Bible British Edition"),("engWycliffe","Wycliffe Bible"),("engylt","Young's Literal Translation"),
]
US_ONLY = {"engBBE"}
for vid, name in EBIBLE_EN:
    note = ""
    if vid.startswith("eng-kjv") or vid == "engkjvcpb":
        note = " In the United Kingdom, Crown letters patent cover printing and importing printed copies."
    if vid in ("engwebp","eng-web-c","engwebpb","eng-webbe","eng-web","engwebu"):
        note = ' "World English Bible" is a trademark of eBible.org; the text may not be called the World English Bible if changed.'
    SOURCES["ebible-" + vid] = dict(name=name + " (eBible.org " + vid + ")",
        licence_class="US-ONLY-PD" if vid in US_ONLY else "PD",
        licence_url=f"https://ebible.org/{vid}/copyright.htm", url=f"https://ebible.org/Scriptures/{vid}_usfm.zip",
        credit=f"{name}. Public domain{' in the United States' if vid in US_ONLY else ''}. Digital text courtesy of eBible.org.{note}",
        licence_quote="Listed under Public Domain Bibles at https://ebible.org/Scriptures/copyright.php")
