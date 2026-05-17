#!/bin/bash

#set -x

dir=$1
if [[ -n "$dir" ]]; then
  cd ${dir}
fi

# ni difinas jam en docker-compose.yml 
# mkdir test-repo
rm -rf test-repo/.git
rm -rf test-repo/*

mkdir -p test-repo && cd test-repo

git init
git config --local init.defaultBranch master
git config --local commit.gpgsign false
#git config receive.denyCurrentBranch warn
git config --local receive.denyCurrentBranch updateInstead

mkdir revo

cat << EOF1 > revo/artefakt.xml
<?xml version="1.0"?>
<!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd">
<vortaro>
<art mrk="\$Id\$">
<kap>
  <rad>artefakt</rad>/o <fnt><bib>SPIV</bib></fnt>
</kap>
<drv mrk="artefakt.0o">
  <kap><tld/>o</kap>
  <snc mrk="artefakt.0o.ARKE">
    <uzo tip="fak">ARKE</uzo>
    <dif>
      <ref tip="dif" cel="art.0efaritajxo.KOMUNE">Artefarita&jcirc;o</ref>,
      objekto prilaborita por iu celo a&ubreve; uzo
      kontraste al a&jcirc;o rezultanta de natura procezo:
      <ekz>
        ritaj <tld/>oj el tombo 268 de la tombejo &Gcirc;arkutan 4B
        <fnt>
          <aut>V. I. Ionesov</aut>
          <vrk><url
          ref="http://www.eventoj.hu/steb/arkeologio/baktrio/baktrio2.htm">
          Kulturo kaj socio de Norda Baktrio</url></vrk>
          <lok>Scienca Revuo, 1992:1 (43), p. 3a-8a</lok>
        </fnt>.
      </ekz>
    </dif>
  </snc>
  <trd lng="fr">artefact</trd>
</drv>
</art>
<!--
\$Log\$
-->
</vortaro>
EOF1

git config --local user.email "neniu@example.com"
git config --local user.name "Ja Neniu"

git add revo
git commit -m"v1"
git tag "v1"

cat << EOF2 > revo/modif.xml
<?xml version="1.0"?>
<!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd">

<vortaro>
<art mrk="\$Id\$">
<kap>
  <ofc>3</ofc>
  <rad>modif</rad>/i
</kap>
<drv mrk="modif.0i">
  <kap><tld/>i</kap>
  <gra><vspec>tr</vspec></gra>
  <snc>
    <dif>
      Parte &scirc;an&gcirc;i ion ne tu&scirc;ante la esencon:
      <ekz>
        <tld/>i la formon de;
      </ekz>
      <ekz>
        <tld/>i projekton, le&gcirc;on, aran&gcirc;on.
      </ekz>
    </dif>
  </snc>
</drv>
</art>
<!--
\$Log\$
-->
</vortaro>
EOF2

git add revo
git commit -m"v2"
git tag "v2"


cat << EOF3 > revo/erar.xml
<?xml version="1.0"?>
<!DOCTYPE vortaro SYSTEM "../dtd/vokoxml.dtd">
<vortaro>
<art mrk="\$Id: erar.xml,v 1.47 2025/03/14 06:18:12 revo Exp \$">
<kap>
  <ofc>*</ofc>
  <rad>erar</rad>/i
</kap>

<drv>
  <kap><ofc>*</ofc><tld/>i</kap>
  <gra><vspec>ntr</vspec></gra>
  <sncx mrk="erar.0i.opinii">
    <dif>
      Deflanki&gcirc;i de la vero, mal&gcirc;uste opinii:
      <ekz>
        vi <tld/>as, sinjoro
        <fnt><bib>Far1</bib>, <lok>&ccirc;apitro 22a</lok></fnt>;
      </ekz>
      <ekz>
        <tld/>i en kalkulo, en gramatiko;
      </ekz>
      <ekz>
        nur tiu ne <tld/>as, kiu neniam ion faras
        <fnt><bib>PrV</bib></fnt>.
      </ekz>
    </dif>
    <refgrp tip="vid">
      <ref cel="tromp.0igxi">trompi&gcirc;i</ref>,
      <ref cel="prav.mal0i">malpravi</ref>.
    </refgrp>
    <trd lng="hu">t&eacute;ved</trd>
    <trdgrp lng="id">
      <trd>keliru</trd>,
      <trd>salah</trd>,
      <trd><baz>salah</baz>bersalah</trd>
    </trdgrp>
    <trdgrp lng="pl">
      <trd>myli&cacute; si&eogonek;</trd>,
      <trd>b&lstroke;&aogonek;dzi&cacute;</trd>
    </trdgrp>
  </snc>
  <snc mrk="erar.0i.peki">
    <dif>
      Deflanki&gcirc;i de la moralaj devoj, peki:
      <ekz>
        de el la ventro de sia patrino la mensogantoj ek<tld/>is
        <fnt><bib>MT</bib>, <lok>&Psa; 58:3</lok></fnt>;
      </ekz>
      <ekz>
        <ind>la <tld/>inta filo</ind>;
        <trd lng="de">der <ind>verlorene Sohn</ind></trd>
        <trd lng="hu">a <ind>t&eacute;kozl&oacute; fi&uacute;</ind></trd>
        <trd lng="ru">&c_b;&c_l;&c_u;&c_d;&c_n;&c_y;&c_j; &c_s;&c_y;&c_n;</trd>
      </ekz>
      <ekz>
        kiu ne pekis, kiu ne <tld/>is
        <fnt>
          <bib>PrV</bib>
        </fnt>?
      </ekz>
    </dif>
    <trd lng="hu">t&eacute;velyeg</trd>
    <trdgrp lng="id">
      <trd><baz>dosa</baz>berdosa</trd>,
      <trd><baz>maksiat</baz>bermaksiat</trd>,
      <trd><baz>buat</baz>berbuat salah</trd>,
      <trd>khilaf</trd>,
      <trd>silap</trd>
    </trdgrp>
    <trd lng="pl">b&lstroke;&aogonek;dzi&cacute;</trd>
  </snc>
</drv>
</art>
</vortaro>
EOF3

git add revo
git commit -m"v3"
git tag "v3"

#git config --global --add safe.directory test_repo/.git

# en la procezujo certigu apartenon al afido
user="afido" group="users" \
id "$user" &>/dev/null && getent group "$group" &>/dev/null && \
chown -R afido:users .git revo

ls -ld .git