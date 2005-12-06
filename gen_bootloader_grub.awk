BEGIN { RS="\n"; FS=""; OFS=""; ORS=""; state="0"; }
{
if(state == "0")
{
	if (match($0, /^title=/) || match($0, /^title */))
	{
		state = "1";
		ORIG = ORIG $0 "\n";
		next;
	} else {
		if(match($0, /^[[:space:]]*#/))
			ORIG = ORIG $0 "\n";
		extraA = extraA $0 "\n";
	}
}

if(state == "1")
{
	if(match($0, /^[[:space:]]*kernel /))
	{
		ORIG = ORIG $0 "\n";
		i = 0;
		have_k = "1";
		my_kernel = $0;
		sub(/kernel-[[:alnum:][:punct:]]+/, "kernel-" KNAME "-" ARCH "-" KV, my_kernel);
	} else {
		if(match($0, /^[[:space:]]*initrd /))
		{
			ORIG = ORIG $0 "\n";
			i = 0;
			extraC = extraC commentLookahead;

			have_i = "1";
			my_initrd = "\n" $0;
			sub(/initr(d|amfs)-[[:alnum:][:punct:]]+/, "init" TYPE "-" KNAME "-" ARCH "-" KV, my_initrd);
		} else {
			if($0 == "\n")
				next;
			ORIG = ORIG $0 "\n";
			if(match($0, /^[[:space:]]*#/))
			{
				i = 1;
				if(commentLookahead)
					commentLookahead = commentLookahead "\n" $0;
				else
					commentLookahead = $0;
				next;
			}

			if(!(match($0, /^title=/) || match($0, /^title */) ))
			{	
				i = 0;
				commentLookahead = "";

				if(have_k != "1")
					extraB = extraB commentLookahead $0 "\n";
				else
				{
					if(have_i != "1")
						extraC = extraC commentLookahead $0 "\n";
					else
						extraD = extraD commentLookahead $0 "\n";
				}
			}
		}
	}
	if(have_k == "1" && ((match($0, /^title=/) || match($0, /^title */)) || NR == LIMIT))
	{
		state = "2";
		print extraA "title=Gentoo Linux (" KV ")\n";
		print extraB my_kernel;
		if(extraC)
			print "\n" extraC;
		print my_initrd extraD "\n";
		if(i == 0)
			print commentLookahead;
		print ORIG;
		next;
	}
}

if(state == "2")
	print $0 "\n";
}
