import java.io.File;
import java.io.FileInputStream;
import java.util.HashMap;
import java.util.Scanner;

public class ParseIvarConfig {
public static void main(String[] args) throws Exception
{
	HashMap<String, String> settingToArg = new HashMap<String, String>();
	settingToArg.put("IVAR_MIN_FREQ_THRESHOLD", "ivarMinFreqThreshold");
	settingToArg.put("IVAR_CONSENSUS_FREQ_THRESHOLD", "ivarFreqThreshold");
	settingToArg.put("IVAR_MIN_DEPTH", "ivarMinDepth");
	settingToArg.put("SCHEME_REPO_PATH", "schemeRepoURL");
	settingToArg.put("SCHEME_VERSION", "schemeVersion");
	settingToArg.put("SCHEME", "scheme");
	
	String configFile = args[0];
	Scanner input = new Scanner(new FileInputStream(new File(configFile)));
	while(input.hasNext())
	{
		String line = input.nextLine();
		if(line.startsWith("#"))
		{
			continue;
		}
		for(String s : settingToArg.keySet())
		{
			if(line.startsWith(s + "=") || line.startsWith(s + "\t"))
			{
				String val = line.substring(s.length() + 1);
                String binDir = System.getProperty("java.class.path");
                val = val.replaceAll("\\$BINDIR", binDir);
				System.out.print(" --" + settingToArg.get(s) + " " + val);
				break;
			}
		}
	}
	System.out.println();
	input.close();
}
}
