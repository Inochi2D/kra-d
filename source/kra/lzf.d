module kra.lzf;

ubyte[] lzfDecompress(ubyte[] input, int length, int maxout)
{
    ubyte[] output = new ubyte[maxout];

    int ip = 0; // input position
    int op = 0; // output position
    int ip_limit = length - 1; // Last index of input array.

    int refer; // index for back reference

    while (ip < ip_limit)
    {
        uint ctrl = input[ip] + 1; // control byte
        uint ofs = (input[ip] & 31) << 8; // distance of back reference.
        uint len = input[ip++] >> 5; // length of back reference.

        if (ctrl < 33)
        {
            // copy the next 'ctrl' number of bytes from the input array to the output array.
            output[op .. op + ctrl] = input[ip .. ip + ctrl];
	    
            ip += ctrl;
            op += ctrl;
        }
        else
        {
            // calculate reference index based on the distance of the back reference.
            len--;
            refer = op - ofs;
            refer--;

            if (len == 7 - 1)
                len += input[ip++];

            refer -= input[ip++]; // adjust index based on length of back reference.

            // check that the reference index isn't out of range
            if (op + len + 3 > maxout || refer < 0)
                return new ubyte[0];

            output[op++] = output[refer++];
            output[op++] = output[refer++];
            output[op++] = output[refer++];

            if (len)
                for (; len > 0; --len)
                    output[op++] = output[refer++];
        }
    }

    return output[0 .. op];
}
