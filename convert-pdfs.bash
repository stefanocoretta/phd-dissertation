
cd ./img/
shopt -s nullglob
for pdf in *{pdf,PDF} ; do
    convert -density 300 "$pdf" "${pdf%%.*}.png"
done
