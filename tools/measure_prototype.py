# Throwaway prototype: builds a sample bible.sqlite to measure size and run checks.
import sqlite3, zipfile, re, os, glob, csv, collections, unicodedata
D='/workspace/bible-study/app/src/dl'; OUT='/workspace/bible-study/app/tools/proto.sqlite'
if os.path.exists(OUT): os.remove(OUT)
db=sqlite3.connect(OUT); c=db.cursor()
c.executescript('''
create table version(id integer primary key, code text, name text);
create table verse(version_id int, book text, ch int, vs int, text text);
create table word(source text, book text, ch int, vs int, pos int, surface text, translit text, gloss text, strong text, morph text);
create table lexicon(strong text, lemma text, translit text, gloss text, def text);
create table crossref(from_ref text, to_ref text, votes int);
''')
stats={}
for z in sorted(glob.glob(D+'/ebible/*_usfm.zip')):
    code=os.path.basename(z)[:-9]
    c.execute('insert into version(code,name) values(?,?)',(code,code)); vid=c.lastrowid
    n=0; books=set()
    with zipfile.ZipFile(z) as zf:
        for nm in zf.namelist():
            if not nm.lower().endswith('.usfm'): continue
            t=zf.read(nm).decode('utf8','ignore')
            m=re.search(r'\\id (\w+)',t); bk=m.group(1) if m else nm
            if bk in ('FRT','GLO','BAK','OTH','INT','CNC','TDX','NDX','XXA','XXB','XXC','XXD','XXE','XXF','XXG'): continue
            ch=0
            for line in re.split(r'(?=\\c |\\v )',t):
                if line.startswith('\\c '): ch=int(re.match(r'\\c (\d+)',line).group(1)); continue
                mv=re.match(r'\\v (\d+)\S*\s(.*)',line,re.S)
                if not mv: continue
                body=re.sub(r'\\f .*?\\f\*|\\x .*?\\x\*','',mv.group(2),flags=re.S)
                body=re.sub(r'\|[^\\]*?(?=\\w\*)','',body)
                body=re.sub(r'\\[a-z0-9+]+\*?','',body); body=re.sub(r'\s+',' ',body).strip()
                c.execute('insert into verse values(?,?,?,?,?)',(vid,bk,ch,int(mv.group(1)),body)); n+=1; books.add(bk)
    stats[code]=(n,len(books))
# Hebrew (TAHOT) and Greek NT (TAGNT)
heb_total=heb_pointed=0; heb_verses=set(); unpointed=[]
POINTS=re.compile('[\u05B0-\u05BC\u05C1\u05C2\u05C7]')
for f in sorted(glob.glob(D+'/TAHOT_*.txt')):
    for line in open(f,encoding='utf8'):
        m=re.match(r'^(\w+)\.(\d+)\.(\d+)(?:\(\d+\.\d+\))?#(\d+)=(\S+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)',line)
        if not m: continue
        bk,ch,vs,pos,typ,heb,tr,gl,st,mo=m.groups()
        c.execute('insert into word values(?,?,?,?,?,?,?,?,?,?)',('TAHOT',bk,int(ch),int(vs),int(pos),heb,tr,gl,st,mo))
        heb_total+=1; heb_verses.add((bk,ch,vs))
        letters=re.sub('[^\u05D0-\u05EA]','',heb)
        if letters and POINTS.search(heb): heb_pointed+=1
        elif letters: unpointed.append((bk,ch,vs,heb,typ))
gnt=0; gnt_verses=set()
for f in sorted(glob.glob(D+'/TAGNT_*.txt')):
    for line in open(f,encoding='utf8'):
        m=re.match(r'^(\w+)\.(\d+)\.(\d+)#(\d+)=(\S+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)',line)
        if not m: continue
        bk,ch,vs,pos,typ,gk,en,sg,lem,ed=m.groups()
        st,_,mo=sg.partition('=')
        c.execute('insert into word values(?,?,?,?,?,?,?,?,?,?)',('TAGNT',bk,int(ch),int(vs),int(pos),gk,'',en,st,mo)); gnt+=1; gnt_verses.add((bk,ch,vs))
# Swete LXX
vers=[l.rstrip('\n').split('\t') for l in open(D+'/swete_vers.csv',encoding='utf8')]
starts=[(int(a),b) for a,b in vers]
idx=0; lxx=0; lxx_verses=set()
for line in open(D+'/swete_words.csv',encoding='utf8'):
    a,_,w=line.rstrip('\n').partition('\t'); a=int(a)
    while idx+1<len(starts) and starts[idx+1][0]<=a: idx+=1
    ref=starts[idx][1]; bk,cv=ref.split('.',1); ch,vs=cv.split(':')
    c.execute('insert into word(source,book,ch,vs,pos,surface) values(?,?,?,?,?,?)',('SWETE',bk,int(ch),int(vs),a,w)); lxx+=1; lxx_verses.add(ref)
# lexicons
for f,src in ((D+'/tbesh.txt','H'),(D+'/tbesg.txt','G')):
    for line in open(f,encoding='utf8'):
        p=line.rstrip('\n').split('\t')
        if len(p)>7 and re.match(r'^[HG]\d{4}',p[0]): c.execute('insert into lexicon values(?,?,?,?,?)',(p[0],p[3],p[4],p[6],p[7]))
for line in open(D+'/cross_references.txt',encoding='utf8'):
    p=line.rstrip('\n').split('\t')
    if len(p)==3 and p[2].lstrip('-').isdigit(): c.execute('insert into crossref values(?,?,?)',p)
c.execute('create index iv on verse(version_id,book,ch,vs)'); c.execute('create index iw on word(source,book,ch,vs)'); c.execute('create index ix on crossref(from_ref)')
db.commit()
print('ENGLISH verses/books:'); [print(' ',k,v) for k,v in stats.items()]
print('TAHOT words',heb_total,'pointed',heb_pointed,'unpointed',len(unpointed),'verses',len(heb_verses)); print(' unpointed sample',unpointed[:8])
print('TAGNT words',gnt,'verses',len(gnt_verses)); print('SWETE words',lxx,'verses',len(lxx_verses))
for t in ('verse','word','lexicon','crossref'): print(t,c.execute(f'select count(*) from {t}').fetchone()[0])
db.execute('vacuum'); db.close(); print('size MB',round(os.path.getsize(OUT)/1e6,1))
