#!/bin/bash

# helpas krei unuopajn eldonojn de Afido
#
eldono=2f

# ni komprenas preparo | kreo | etikedo
target="${1:-helpo}"


case $target in
preparo)
    # kontrolu ĉu la branĉo kongruas kun la agordita versio
    branch=$(git symbolic-ref --short HEAD)
    if [ "${branch}" != "${eldono}" ]; then
        echo "Ne kongruas la branĉo (${branch}) kun la eldono (${eldono})"
        echo "Agordu la variablon 'eldono' en tiu ĉi skripto por prepari novan eldonon."
        exit 1
    fi

    #echo "Aktualigante skriptojn al nova eldono ${eldono}..."
    #sed -i 's/"version": "[1-9].[0-9].[1-9]"/"version": "'${node_release}'"/' ${PACKG}
    ;;
kreo)
    echo "Kreante lokan procezujon (por docker) voko-afido"
    docker build --build-arg VG_TAG=v${eldono} --build-arg ZIP_SUFFIX=${eldono} \
           -t voko-afido .
    ;;    
etikedo)
    echo "Provizante la aktualan staton per etikedo (git tag) v${eldono}"
    echo "kaj puŝante tiun staton al la centra deponejo"
    git tag -f v${eldono} && git push && git push --tags -f
    ;;

helpo | *)
    echo "---------------------------------------------------------------------------"
    echo "Tiu skripto servas por prepari kaj krei unuopajn eldonojn."
    echo "Tiucele ekzistas celoj 'preparo', 'kreo', 'etikedo'."
    echo ""
    echo "Per la aparta celo 'preparo' oni povas krei git-branĉon kun nova eldono por tie "
    echo "komenci programadon de novaj funkcioj, ŝanĝoj ktp. Antaŭ adaptu en la kapo de ĉi-skripto"
    echo "la variablon 'eldono' al la nova eldono."
    echo "Per la celo 'etikedo' vi provizas aktualan staton per 'git tag', necesa por "
    echo "ke kompiliĝu ĉe Github nova eldono de procezujo 'docker'."
    ;;    
esac
