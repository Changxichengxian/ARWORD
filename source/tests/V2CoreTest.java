import com.wordfrontier.app.*;
import org.json.*;
import java.util.*;
public class V2CoreTest {
  static int n;
  static void ok(boolean value,String message){n++;if(!value)throw new AssertionError(message);}
  static double estimate(double ability,long seed){Random r=new Random(seed);JSONObject p=Adaptive.begin();for(int i=0;i<24;i++){int b=Adaptive.band(p);double probability=.25+.75/(1+Math.exp((b-ability)*1.25));Adaptive.answer(p,b,r.nextDouble()<probability,true);}Adaptive.validate(p);return p.optDouble("theta");}
  public static void main(String[] args)throws Exception{
    JSONObject all=Adaptive.begin(),none=Adaptive.begin();for(int i=0;i<24;i++){Adaptive.answer(all,Adaptive.band(all),true,true);Adaptive.answer(none,Adaptive.band(none),false,false);}ok(all.optDouble("theta")>7,"ceiling reached");ok(none.optDouble("theta")<0,"floor reached");
    double easy=0,hard=0;for(int i=0;i<100;i++){easy+=estimate(1,i);hard+=estimate(6,i);}ok(hard/100>easy/100+2,"ordering under simulated response model");
    Game frequency=new Game(5);Game.put(frequency.s,"wordBand",3);for(int i=0;i<8;i++)frequency.recordFrequency(3,true,false);ok(frequency.s.optInt("wordBand")==4,"frequency advances");for(int i=0;i<8;i++)frequency.recordFrequency(1,true,false);ok(frequency.s.optInt("wordBand")==4,"easier reviews cannot inflate band");for(int i=0;i<8;i++)frequency.recordFrequency(4,true,true);ok(frequency.s.optInt("wordBand")==3,"assisted answers lower difficulty");
    for(int seed=1;seed<=500;seed++){
      Game g=new Game(seed);g.start(seed%4,seed%3, false,1);Game.put(g.battle(),"v2",true);
      int rounds=0;while(!g.battleOver()&&rounds<8){JSONObject b=g.battle();g.answer(true,false,0);ok(b.optInt("focus")<=3,"focus capped");int committed=b.optInt("committed");if(b.optInt("focus")>=2){int kind=seed%2;if(kind==1&&b.optInt("hp")>=36)kind=0;ok(g.ability(kind),"ability accepted");ok(!g.ability(kind),"once per round");ok(b.optInt("committed")==committed,"does not alter committed action");if(kind==0)ok(b.optInt("report")==committed,"truthful insight");}
        Game.put(b,"phase","tactic");int action=(committed+1)%3;if(!Game.canUse(action,b.optInt("energy")))action=1;g.choose(action);g.resolve(1);ok(b.optInt("hp")<=36,"heal cannot exceed max");Game.validate(g.s);g=new Game(new JSONObject(g.s.toString()));rounds++;if(!g.battleOver())g.prepareRound();
      }g.finish();int materials=g.s.optInt("materials");g.finish();ok(g.s.optInt("materials")==materials,"reward only once");
    }
    System.out.println("PASS "+n+" v2 assertions; 500 complete battles, 200 synthetic response paths");
  }
}
