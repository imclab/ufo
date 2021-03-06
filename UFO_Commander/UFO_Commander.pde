import controlP5.*;
import oscP5.*;
import netP5.*;
import processing.serial.*; 

import java.util.LinkedList;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


final boolean DEBUG = true; // osc
final boolean DEBUG_SERIAL = true;


final String PRESET_FILE = "presets.txt";
final String SERIAL_PORT = "/dev/tty.usbserial-A501E2IQ";
final int INITIAL_PATTERN = 80;

final int BAUD_RATE = 9600;
final int MESSAGE_SIZE = 14;
final int TIMING_ADDR = 129;
final int OFF_PATTERN = 68;
final int DELIMETER = 128;
final int INTERVAL = 100;

int lastHeartbeat;

boolean stealth = false;

ArrayList lightGroups = new ArrayList();
ArrayList presets = new ArrayList();

LightGroup groupAll;
// LightGroup groupHorizontalPoles;
// LightGroup groupVerticalPoles;
LightGroup groupBoxes;
// LightGroup groupDMX;
LightGroup groupPoles;

// ControlP5

final int LIGHT_GROUP_WIDTH = 270;
final int RADIO_SIZE = 20;
final int PADDING = 15;

ControlP5 controlP5;

String[] patterns = new String[127];
String[] mappings = new String[6];

ListBox presetList;
Textfield presetNamer;

boolean sympathizeEvents = false;

Serial port;
LinkedList messageQueue = new LinkedList();

// OSCP5

OscP5 oscP5;
NetAddress myRemoteLocation;
NetAddress myCompLocation;

String IPAD_ADDRESS = "192.168.1.9";
int IPAD_PORT = 8000;
int MY_PORT = 12001;

// Map of which groups to address.
// In order of the lightGroups array.
// Object cuz oscP5.
// Object[] activeAddr = { 1.0, 0.0, 0.0, 0.0, 0.0 };
Object[] activeAddr = { 1.0, 0.0, 0.0 };

int[] patternsToIndeces;

void setup() {
  
  Matcher m = Pattern.compile("/preset/(\\d+)").matcher("/preset/23");

  m.find();
  println(m.group(1));



  size(830, 675);

  patterns[80] = "pulseOnce";
  patterns[79] = "colorWipeMeterGradient";
  patterns[78] = "colorWipeMeter";
  patterns[77] = "colorChase";
  patterns[76] = "stripe";
  patterns[75] = "colorAlternator";
  patterns[74] = "colorWipe";
  patterns[73] = "bounce";
  patterns[72] = "pulseSaw";
  patterns[71] = "pulseSine";
  patterns[70] = "gradient";
  patterns[69] = "solidColor";
  patterns[OFF_PATTERN] = "off";
  patterns[66] = "rainbow";
  patterns[65] = "rainbowCycle";
  patterns[64] = "totesRandom";
  patterns[63] = "flickerStrobeFour";
  patterns[62] = "flickerStrobeTwo";

  mappings[1] = "forward";
  mappings[2] = "backward";
  mappings[3] = "peak";
  mappings[4] = "valley";
  mappings[5] = "dither";

  controlP5 = new ControlP5(this);

  // Only instantiate port if we know for sure it exists.
  // Port won't be null if you give it a bunk address.
  String[] serialPorts = Serial.list();
  println (serialPorts);
  for (int i = 0; i < serialPorts.length; i++) {
    if (serialPorts[i].equals(SERIAL_PORT)) {
      port = new Serial(this, SERIAL_PORT, BAUD_RATE);  
    }
  }
  if (port != null) {
    println("Using serial port " + SERIAL_PORT);
  } else { 
    println("Did not find a serial port!");
  }

  // Think of this as push/pop/sympathizeEvents
  // first run of controlEvent causes probs when not all 
  // controllers have been created.
  sympathizeEvents = true;

  groupAll = new LightGroup("All", 0) ;
  // groupHorizontalPoles = new LightGroup("Horizontal Poles", 0);
  // groupVerticalPoles = new LightGroup("Vertical Poles", 7);
  groupPoles = new LightGroup("Poles", 1);
  groupBoxes = new LightGroup("Boxes", 2);

  sympathizeEvents = false;



  int x = lightGroups.size() * LIGHT_GROUP_WIDTH + PADDING;
  
  presetNamer = controlP5.addTextfield("preset-namer")
                         .setPosition(PADDING, PADDING*2)
                         .setLabel("Save preset.")
                         .setSize(LIGHT_GROUP_WIDTH, 20)
                         .moveTo("presets");

  presetList = controlP5.addListBox("preset-list")
                        .setPosition(PADDING, PADDING*2 + 70)
                        .setSize(LIGHT_GROUP_WIDTH, 600)
                        .setItemHeight(20)
                        .actAsPulldownMenu(false)
                        .moveTo("presets");

  oscP5 = new OscP5(this, MY_PORT);
  myRemoteLocation = new NetAddress(IPAD_ADDRESS, IPAD_PORT);
  myCompLocation = new NetAddress(oscP5.ip(), MY_PORT);

  loadPresets();
  synchronizePatterns();
  synchronizeMappings();

}

void draw() {
 
  background(0);

  if (port != null) heartbeat();

  // checks for the existence of port itself
  // still debugs if port isn't there
  if (!stealth) emptyMessageQueue();

}

void sendAllMessages() {
  for (int i = 0; i < lightGroups.size(); i++) {
    LightGroup l = (LightGroup)lightGroups.get(i);
    l.sendMessage();
  }
}

void emptyMessageQueue() {

  while (messageQueue.peek() != null) {
    byte b = ((Byte)messageQueue.poll()).byteValue();
    if (port != null) port.write(b);
    if (DEBUG_SERIAL) println("[SERIAL] " + b);
  }

}

void heartbeat() {
  int now = millis();
  if (now - lastHeartbeat >= INTERVAL) {
    port.write(TIMING_ADDR);
    port.write(new Integer(now).toString());
    port.write(DELIMETER);
    lastHeartbeat = now;
  }
}

void controlEvent(ControlEvent theEvent) {

  LightGroup l = checkLightControllers(theEvent);

  if (keyPressed || l == groupAll) expressSympathy(theEvent);

  if (theEvent.isFrom(presetNamer)) {
    savePreset(theEvent.getStringValue());
    return;
  }

  if (theEvent.isFrom(presetList)) {
    applyPreset((int)theEvent.value());
  }

}

void expressSympathy(ControlEvent theEvent) {

  if (!sympathizeEvents) {
    
    sympathizeEvents = true;

    String name = theEvent.name();
    name = name.substring(0, name.indexOf("-"));

    for (Object o : lightGroups) {

      LightGroup l = (LightGroup)o;
      String addr = name + "-" + l.address;
      Controller c = controlP5.getController(addr);
      
      // Controller groups are weird.
      if (theEvent.isGroup() && theEvent.getGroup() instanceof ColorPicker) {
        
        if (name.equals("picker1")) {
          l.setColor1((int)theEvent.value());
        } else if (name.equals("picker2")) {
          l.setColor2((int)theEvent.value());
        }

      } else if (theEvent.isGroup() && theEvent.getGroup() instanceof RadioButton) {

        if (name.equals("patterns")) {
          l.setPattern((int)theEvent.value());
        } else if (name.equals("mappings")) { 
          l.setMapping((int)theEvent.value());
        }

      } else if (c != null) {

        c.setValue(theEvent.value());

      }


    }

    sympathizeEvents = false;

  }

}

/**
 * Returns Light group controller came from or null if none.
 */
LightGroup checkLightControllers(ControlEvent theEvent) {

  for (Object o : lightGroups) {

    LightGroup l = (LightGroup)o;

    // h8 u cp5
    // Would have liked to do all listeners, but I couldn't, because there
    // are controller groups. Just did it all here to be consistent.

    if (theEvent.isFrom(l.bang)) {
      l.sendMessage();
      return l;
    }

    if (theEvent.isFrom(l.rateSlider)) {
      l.rate = (int)theEvent.value();
      return l;
    }

    if (theEvent.isFrom(l.brightnessSlider)) {
      l.brightness = (int)theEvent.value();
      return l;
    }

    if (theEvent.isFrom(l.patternList)) {
      l.pattern = (int)theEvent.value();
      return l;
    }

    if (theEvent.isFrom(l.mappingList)) {
      l.mapping = (int)theEvent.value();
      return l;
    }

    if (theEvent.isFrom(l.colorPicker1)) {
      l.color1 = (color)theEvent.value();
      return l;
    }

    if (theEvent.isFrom(l.colorPicker2)) {
      l.color2 = (color)theEvent.value();
      return l;
    }

  }

  return null;

}

void applyPreset(int presetIndex) {

  LightGroupSettings[] preset = (LightGroupSettings[])presets.get(presetIndex);
  
  for (int i = 0; i < lightGroups.size(); i++) {
    LightGroup l = (LightGroup)lightGroups.get(i);
    l.applySettings(preset[i]);
  }

  sendAllMessages();

}

void savePreset(String presetName) {

  LightGroupSettings[] preset = new LightGroupSettings[lightGroups.size()];

  for (int i = 0; i < lightGroups.size(); i++) {
    LightGroup l = (LightGroup)lightGroups.get(i);
    preset[i] = l.getSettings();
  }

  presets.add(preset);
  presetList.addItem(presetName, presets.size()-1);

  writePresets();

}

void writePresets() {

  PrintWriter output = createWriter(PRESET_FILE);

  for (int i = 0; i < presets.size(); i++) {

    LightGroupSettings[] l = (LightGroupSettings[])presets.get(i);
    String[] serialized = new String[l.length];

    String name = presetList.getItem(i).getName();

    for (int j = 0; j < serialized.length; j++) {
      serialized[j] = l[j].serialize();
    }

    output.println(name + ":" + join(serialized, ":"));

  }

  output.flush();
  output.close();

  synchronizePresets();

}

void loadPresets() {

  BufferedReader reader = createReader(PRESET_FILE);

  String line = null;

  do { 
    
    try {
      line = reader.readLine();
    } catch (IOException e) {
      e.printStackTrace();
      line = null;
    }

    if (line != null) {
      parsePreset(line);
    }

  } while (line != null);

  synchronizePresets();

}

void synchronizePresets() {

  String[] s = new String[presets.size()];
  for (int i = 0; i < s.length; i++) {
    s[i] = presetList.getItem(i).getName();
  }

  OscMessage message = new OscMessage("/Presets/setLabels");
  message.add(s);
  oscP5.send(message, myRemoteLocation);

}

void synchronizePatterns() {

  // count non-null presets
  int numPatterns = 0;
  for (int i = 0; i < patterns.length; i++) {
    if (patterns[i] != null) {
      numPatterns++;
    }
  }

  patternsToIndeces = new int[numPatterns];

  // make arr
  String[] s = new String[numPatterns];
  int j = 0;
  for (int i = 0; i < patterns.length; i++) {
    if (patterns[i] != null) {
      s[j] = patterns[i];
      patternsToIndeces[j] = i;
      j++;
    }
  }

  OscMessage message = new OscMessage("/Patterns/setLabels");
  message.add(s);
  oscP5.send(message, myRemoteLocation);

}

void synchronizeMappings() {

  // count non-null presets
  int numMappings = 0;
  for (int i = 0; i < mappings.length; i++) {
    if (mappings[i] != null) {
      numMappings++;
    }
  }

  // make arr
  String[] s = new String[numMappings];
  int j = 0;
  for (int i = 0; i < mappings.length; i++) {
    if (mappings[i] != null) {
      s[j] = mappings[i];
      j++;
    }
  }

  OscMessage message = new OscMessage("/Mappings/setLabels");
  message.add(s);
  oscP5.send(message, myRemoteLocation);

}

void parsePreset(String s) {
  
  String[] data = split(s, ":");

  LightGroupSettings[] preset = new LightGroupSettings[data.length-1];

  for (int i = 0; i < preset.length; i++) {
    preset[i] = new LightGroupSettings(data[i+1]);
  }

  presets.add(preset);
  presetList.addItem(data[0], presets.size()-1);

}
