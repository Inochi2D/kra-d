module kra.lzf;
import std.stdio;

/**
   Taken from Krita source code

   https://invent.kde.org/graphics/krita/-/blob/master/libs/image/tiles3/swap/kis_lzf_compression.cpp#L173
 */
int lzfDecompress(ubyte[] input, size_t length, ubyte[] output, size_t maxout)
{
	const(ubyte)* ip = cast(const(ubyte)*) input;
	const(ubyte)* ip_limit = ip + length - 1;
	ubyte* op = cast(ubyte*) output;
	ubyte* op_limit = op + maxout;
	ubyte* refer;

	while (ip < ip_limit)
	{
		uint ctrl = (*ip) + 1;
		uint ofs = ((*ip) & 31) << 8;
		uint len = (*ip++) >> 5;

		if (ctrl < 33)
		{
			if (op + ctrl > op_limit)
				return 0;

			if (ctrl)
			{
				*op++ = *ip++;
				ctrl--;

				if (ctrl)
				{
					*op++ = *ip++;
					ctrl--;

					for (; ctrl; ctrl--)
						*op++ = *ip++;
				}
			}
		}
		else
		{
			/* back reference */
			len--;
			refer = op - ofs;
			refer--;

			if (len == 7 - 1)
				len += *ip++;

			refer -= *ip++;

			if (op + len + 3 > op_limit)
				return 0;

			if (refer < cast(ubyte*) output)
				return 0;

			*op++ = *refer++;
			*op++ = *refer++;
			*op++ = *refer++;

			if (len)
				for (; len; --len)
					*op++ = *refer++;
		}
	}
	return cast(int)(op - cast(ubyte*) output);
}
