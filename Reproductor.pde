import controlP5.*;
//import processing.sound.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;
import java.util.*;
import java.net.InetAddress;
import javax.swing.*;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;
import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;


Slider volu;
static String INDEX_NAME = "canciones";
static String DOC_TYPE = "cancion";
ControlP5 play, vol, knob;
ScrollableList list;
Minim mini;
AudioMetaData a;
AudioPlayer song;
FilePlayer s;
int z;
float flag=0;
String m, archivo;
String[] dir;
LowPassSP lpf;
AudioOutput output;
FFT fftLin;
boolean sound=false, high=false, low=false, con=false;
int y=0;

Client client;
Node node;

void setup() {
  size(600, 600);
  dir = new String[100];
  Settings.Builder settings = Settings.settingsBuilder();
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);

  node = NodeBuilder.nodeBuilder()
    .settings(settings)
    .clusterName("mycluster")
    .data(true)
    .local(true)
    .node();

  selectInput("Seleccciona un archivo:", "fileSelected");
  client = node.client();

  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }


  play = new ControlP5(this);  
  vol = new ControlP5(this);

  play.addButton("play")
    .setValue(0)
    .setPosition(50, 50)
    .setSize(50, 50)
    .setImages(loadImage("pause1.jpg"), loadImage("pause2.jpg"), loadImage("play3.jpg"));

  play.addButton("pause")
    .setValue(0)
    .setPosition(140, 55)
    .setSize(50, 50)
    .setImages(loadImage("play1.jpg"), loadImage("play2.jpg"), loadImage("pause3.jpg"));

  play.addButton("mute")
    .setValue(0)
    .setPosition(225, 55)
    .setSize(50, 50)
    .setImages(loadImage("mute1.jpg"), loadImage("mute2.jpg"), loadImage("mute3.jpg"));

  play.addButton("unmute")
    .setValue(0)
    .setPosition(310, 55)
    .setSize(50, 50)
    .setImages(loadImage("unmute1.jpg"), loadImage("unmute2.jpg"), loadImage("unmute3.jpg"));

  play.addButton("stop")
    .setValue(0)
    .setPosition(390, 55)
    .setSize(50, 50)
    .setImages(loadImage("stop1.jpg"), loadImage("stop2.jpg"), loadImage("stop3.jpg"));

  play.addButton("choose")
    .setValue(0)
    .setPosition(480, 55)
    .setSize(50, 50);

  play.addButton("importFiles")
    .setPosition(545, 55)
    .setLabel("Importar")
    .setSize(50, 50);

  vol.addSlider("volume")
    .setValue(100)
    .setPosition(50, 135)
    .setSize(200, 50)
    .setRange(0, 100);

  /*knob.addSlider("agudos")
   .setValue(100)
   .setPosition(300, 135)
   .setSize(60, 60)
   .setRange(0,100);*/
  //file = new SoundFile(this, "Shura.mp3");
  //stop = new ControlP5(this);    
  mini = new Minim(this);
  output = mini.getLineOut();
  //song = mini.loadFile("B_long.wav", 1024);
  lpf = new LowPassSP(100, output.sampleRate());

  list = play.addScrollableList("playlist")
    .setPosition(50, 270)
    .setSize(300, 200)
    .setBarHeight(20)
    .setItemHeight(20)
    .setType(ScrollableList.LIST);

  loadFiles();
}

void draw() {
  stroke(255);
  // we multiply the values returned by get by 50 so we can see the waveform
  for ( int i = 0; i < output.bufferSize() - 1; i++ )
  {
    float x1 = map(i, 0, output.bufferSize(), 0, width);
    float x2 = map(i+1, 0, output.bufferSize(), 0, width);
    line(x1, 500 - output.left.get(i)*50, x2, 500 - output.left.get(i+1)*50);
    line(x1, 3*height/4 - output.right.get(i)*50, x2, 3*height/4 - output.right.get(i+1)*50);
  }
}

void importFiles() {
  JFileChooser jfc = new JFileChooser();
  jfc.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  jfc.setMultiSelectionEnabled(true);
  jfc.showOpenDialog(null);     

  for (File f : jfc.getSelectedFiles()) {

    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }
    AudioPlayer song = mini.loadFile(f.getAbsolutePath()); 
    AudioMetaData meta = song.getMetaData();

    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());
    try {

      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc)
        .execute()
        .actionGet();

      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}

void playlist(int n) {
  println(list.getItem(n)); 
  song.pause();
  song.rewind();
  song = mini.loadFile(dir[n], 1024);
  song.play();
}

void loadFiles() {
  try {
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    for (SearchHit hit : response.getHits().getHits()) {
      // Cada resultado lo agregamos a la lista
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}

void addItem(Map<String, Object> doc) {
  // Se agrega a la lista. El primer argumento es el texto a desplegar en la lista, el segundo es el objeto que queremos que almacene
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
  archivo=doc.get("path")+"";
  dir[y]=archivo;
  y += 1;
}

void fileSelected(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel.");
  } else {
    m = selection.getAbsolutePath();
    song = mini.loadFile(m);
    println("Cancion seleccionada " + selection.getAbsolutePath());
    a = song.getMetaData();
  }
}

public void play() {
  song.play();
  println("play");
  textSize(14);
  text("Nombre: " + a.fileName(), 50, 200);
  text("Titulo: " + a.title(), 50, 215);
  text("Autor: " + a.author(), 50, 230);
  text(a.album(), 50, 245);
}

public void pause() {
  song.pause(); 
  println("pause");
}

public void mute() {
  song.mute();
  println("mute");
}

public void unmute() {
  song.unmute();
  println("unmute");
}

public void stop() {
  song.pause();
  song.rewind();
}    

public void choose() {
  song.pause();
  song.rewind();     
  selectInput("Selecciona canción: ", "fileSelected");
}

void controlEvent (ControlEvent evento) // se activa el evento
{
  flag = int(evento.getController().getValue()); // recoje el valor del slider y lo convierte en entero
  flag = flag-25;
  song.setGain(flag);
}