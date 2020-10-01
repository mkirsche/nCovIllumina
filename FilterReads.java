import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Scanner;

public class FilterReads {
public static void main(String[] args) throws IOException
{
	int minLength = Integer.parseInt(args[0]);
	int maxLength = Integer.parseInt(args[1]);
	
	String[] fns = new String[args.length - 2];
	for(int i = 0; i<fns.length; i++)
	{
		fns[i] = args[i+2];
	}
	Arrays.sort(fns);
	for(int a = 0; a+1<fns.length; a+=2)
	{
		String read1Fn = fns[a];
		String read2Fn = fns[a+1];
		Scanner input1 = new Scanner(new FileInputStream(new File(read1Fn)));
		Scanner input2 = new Scanner(new FileInputStream(new File(read2Fn)));
		ArrayList<String> output1 = new ArrayList<String>(), output2 = new ArrayList<String>();
		while(input1.hasNext() && input2.hasNext())
		{
			String[] read1 = new String[4], read2 = new String[4];
			for(int i = 0; i<4; i++)
			{
				read1[i] = input1.nextLine();
				read2[i] = input2.nextLine();
			}
			int length1 = read1[1].length();
			int length2 = read2[1].length();
			if(Math.min(length1, length2) < minLength || Math.max(length1, length2) > maxLength)
			{
				continue;
			}
			for(int i = 0; i<4; i++)
			{
				output1.add(read1[i]);
				output2.add(read2[i]);
			}
		}
		input1.close();
		input2.close();
		
		new File(read1Fn).delete();
		new File(read2Fn).delete();
		
		PrintWriter out1 = new PrintWriter(new File(read1Fn));
		PrintWriter out2 = new PrintWriter(new File(read2Fn));
		
		for(int i = 0; i<output1.size(); i++)
		{
			out1.println(output1.get(i));
			out2.println(output2.get(i));
		}
		
		out1.close();
		out2.close();
	}
}
}
