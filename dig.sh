d () {
	R=""
	for A in $@ ; do
		T=$(echo $A | sed -r 's#^http(s)?://([^/]+)/?#\2#')
		R="$R $T"
	done
	/usr/bin/dig ANY +noall +answer $R
}