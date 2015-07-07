<!DOCTYPE HTML>
<%
########################################################################################################################
#----------------------------------------------------------------------------------------------------------------------#
import commands, sys, os, json, subprocess, uuid;
reload(sys);
sys.setdefaultencoding('utf8');

bratdsl = """{
     def idx = 0
     def lastview = &$payload.views[-1]
     def lastviewanns = lastview==null?null:lastview.annotations
     def lastviewfeatures = lastviewanns==null?null:lastviewanns.features
     def parse = lastviewfeatures == null? null:lastviewfeatures.select{&.penntree!=null}.penntree
     def coref = lastviewanns.select{&."@type" != null && &."@type".contains("Coreference")}.features.mentions
     def markables = lastviewanns.select{&."@type" != null && &."@type".contains("Markable") && coref.toString().contains(&.id)}

     text &$payload.text."@value" +  (parse == null||parse.size == 0||parse[0]==null?"":"\n~~~~\n"+parse[0])

     relations (lastviewanns.select{&."@type" != null && &."@type".contains("DependencyStructure")}.features.dependencies
                .flatten().foreach{
                ["D${idx++}", &.label, [["Governor", &.features.governor], ["Dependent", &.features.dependent]]]
                })

     equivs (lastviewanns.select{&."@type" != null && &."@type".contains("Coreference")}.features
                .flatten().foreach{
                                 ["*", "Coreference", &.mentions[0], &.mentions[1]]
                                 })

     entities (lastviewanns.unique{&.start+" "+&.end}.select{&.features != null && (&.features.category != null || &.features.pos != null)}.foreach{
       [&.id == null?"T${idx++}":&.id, &.features.category != null?&.features.category.trim().toUpperCase():&.features.pos.trim().toUpperCase(), [[&.start.toInteger(), &.end.toInteger()]]]
     } + markables.foreach{
       [&.id == null?"M${idx++}":&.id, "Mention", [[&.start.toInteger(), &.end.toInteger()]]]
     })
}
"""

bratconf = """
{"entity_types":[{"type":"PERSON","labels":["Person","Per"],"bgColor":"#ffccaa","borderColor":"darken"},{"type":"TIME","labels":["Time"],"bgColor":"#ffccaa","borderColor":"darken"},{"type":"NUMBER","labels":["Number","Num"],"bgColor":"#ffccaa","borderColor":"darken"},{"type":"DATE","labels":["Date"],"bgColor":"#ffccaa","borderColor":"darken"},{"type":"LOCATION","labels":["Location","Loc"],"bgColor":"#f1f447","borderColor":"darken"},{"type":"ORGANIZATION","labels":["Organization","Org"],"bgColor":"#8fb2ff","borderColor":"darken"},{"type":"GENE","labels":["Gene","Gen"],"bgColor":"#95dfff","borderColor":"darken"},{"type":"-LRB-","labels":["-LRB-"],"bgColor":"#e3e3e3","borderColor":"darken","fgColor":"black"},{"type":"-RRB-","labels":["-RRB-"],"bgColor":"#e3e3e3","borderColor":"darken","fgColor":"black"},{"type":"DT","labels":["DT"],"bgColor":"#ccadf6","borderColor":"darken","fgColor":"black"},{"type":"PDT","labels":["PDT"],"bgColor":"#ccadf6","borderColor":"darken","fgColor":"black"},{"type":"WDT","labels":["WDT"],"bgColor":"#ccadf6","borderColor":"darken","fgColor":"black"},{"type":"CC","labels":["CC"],"bgColor":"white","borderColor":"darken","fgColor":"black"},{"type":"CD","labels":["CD"],"bgColor":"#ccdaf6","borderColor":"darken","fgColor":"black"},{"type":"NP","labels":["NP"],"bgColor":"#7fa2ff","borderColor":"darken","fgColor":"black"},{"type":"NN","labels":["NN"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"NNP","labels":["NNP"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"NNPS","labels":["NNPS"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"NNS","labels":["NNS"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"VP","labels":["VP"],"bgColor":"lightgreen","borderColor":"darken","fgColor":"black"},{"type":"MD","labels":["MD"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VB","labels":["VB"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VBZ","labels":["VBZ"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VBP","labels":["VBP"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VBN","labels":["VBN"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VBG","labels":["VBG"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"VBD","labels":["VBD"],"bgColor":"#adf6a2","borderColor":"darken","fgColor":"black"},{"type":"PP","labels":["PP"],"bgColor":"lightblue","borderColor":"darken","fgColor":"black"},{"type":"PRP","labels":["PRP"],"bgColor":"#ccdaf6","borderColor":"darken","fgColor":"black"},{"type":"RB","labels":["RB"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"RBR","labels":["RBR"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"RBS","labels":["RBS"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"WRB","labels":["WRB"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"WP","labels":["WP"],"bgColor":"#ccdaf6","borderColor":"darken","fgColor":"black"},{"type":"ADVP","labels":["ADVP"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"SBAR","labels":["SBAR"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"ADJP","labels":["ADJP"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"JJ","labels":["JJ"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"JJS","labels":["JJS"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"JJR","labels":["JJR"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"PRT","labels":["PRT"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"CONJP","labels":["CONJP"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"TO","labels":["TO"],"bgColor":"#ffe8be","borderColor":"darken","fgColor":"black"},{"type":"IN","labels":["IN"],"bgColor":"#ffe8be","borderColor":"darken","fgColor":"black"},{"type":"INTJ","labels":["INTJ"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"EX","labels":["EX"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"FW","labels":["FW"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"LS","labels":["LS"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"POS","labels":["POS"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"RP","labels":["RP"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"SYM","labels":["SYM"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"UH","labels":["UH"],"bgColor":"#e4cbf6","borderColor":"darken","fgColor":"black"},{"type":"LST","labels":["LST"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"MENTION","labels":["Mention"],"bgColor":"lightgray","borderColor":"darken","fgColor":"black"},{"type":"B-DNA","labels":["B-DNA","BDNA"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"I-DNA","labels":["I-DNA","IDNA"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"B-PROTEIN","labels":["B-PROTEIN","B-PRO","BPRO"],"bgColor":"#ffe8be","borderColor":"darken","fgColor":"black"},{"type":"I-PROTEIN","labels":["I-PROTEIN","I-PRO","IPRO"],"bgColor":"#ffe8be","borderColor":"darken","fgColor":"black"},{"type":"B-CELL_TYPE","labels":["B-CELL_TYPE","B-CELL","BCELL"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"I-CELL_TYPE","labels":["B-CELL_TYPE","I-CELL","ICELL"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"DNA","labels":["DNA"],"bgColor":"#a4bced","borderColor":"darken","fgColor":"black"},{"type":"PROTEIN","labels":["PROTEIN","PROT"],"bgColor":"#ffe8be","borderColor":"darken","fgColor":"black"},{"type":"CELL_TYPE","labels":["CELL-TYPE","CELL-T"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"},{"type":"CELL_LINE","labels":["CELL_LINE","CELL-L"],"bgColor":"#fffda8","borderColor":"darken","fgColor":"black"}],"entity_attribute_types":[],"relation_types":[{"args":[{"role":"Arg1","targets":["Mention"]},{"role":"Arg2","targets":["Mention"]}],"arrowHead":"none","name":"Coref","labels":["Coreference","Coref"],"children":[],"unused":false,"dashArray":"3,3","attributes":[],"type":"Coreference","properties":{"symmetric":true,"transitive":true}}],"event_types":[{"borderColor":"darken","normalizations":[],"name":"Mention","arcs":[{"arrowHead":"none","dashArray":"3,3","labels":["Coref"],"type":"Coreference","targets":["Mention"]}],"labels":["Mention","Ment","M"],"unused":false,"bgColor":"#ffe000","attributes":[],"type":"Mention","children":[]}]}
"""

########################################################################################################################

lappsjson = hda.get_raw_data();
projhome = commands.getstatusoutput("pwd")[1]
lsdpath = projhome + '/config/plugins/visualizations/nlp_brat/json2json.lsd'
lsjson2json = commands.getstatusoutput("ls "+lsdpath)[1]

json2jsonin = json.JSONEncoder().encode({
    "discriminator": "http://vocab.lappsgrid.org/ns/media/jsonld",
    "payload": {
    "metadata": {
    "op": "json2jsondsl",
    "template":bratdsl },
    "@context": "http://vocab.lappsgrid.org/context-1.0.0.jsonld",
    "sources": [lappsjson] }
})

fil = projhome+"/json2jsonin_"+str(uuid.uuid4())+".txt"
with open(fil, "w") as text_file:
    text_file.write(json2jsonin)

output = subprocess.Popen([lsdpath, fil], stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
outputjson = output.stdout.read()
bratjson = ""
if not "http://vocab.lappsgrid.org/ns/error" in outputjson:
    bratjson = json.loads(outputjson)["payload"]["targets"][0]
json2jsonexp = output.stderr

os.remove(fil)
%>


<%
root = h.url_for( '/' )
%>

<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, user-scalable=no, minimum-scale=1.0, maximum-scale=1.0">

    <title>${hda.name} | ${visualization_name}</title>


    ${h.stylesheet_link( root + 'plugins/visualizations/nlp_brat/static/css/style-vis.css' )}
    ${h.stylesheet_link( root + 'plugins/visualizations/nlp_brat/static/css/bootstrap-theme.min.css' )}
    ${h.stylesheet_link( root + 'plugins/visualizations/nlp_brat/static/css/bootstrap.min.css' )}
    ${h.stylesheet_link( root + 'plugins/visualizations/nlp_brat/static/css/theme.css' )}

    ${h.javascript_link( root + 'plugins/visualizations/nlp_brat/static/js/head.load.min.js' )}


    <script>
        head.js(
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.svg.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.svgdom.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/jquery-ui.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/webfont.js',
            '${root}plugins/visualizations/nlp_brat/static/js/util.js',
            '${root}plugins/visualizations/nlp_brat/static/js/annotation_log.js',
            '${root}plugins/visualizations/nlp_brat/static/js/dispatcher.js',
            '${root}plugins/visualizations/nlp_brat/static/js/url_monitor.js',
            '${root}plugins/visualizations/nlp_brat/static/js/visualizer.js',
            '${root}plugins/visualizations/nlp_brat/static/js/configuration.js',
            '${root}plugins/visualizations/nlp_brat/static/js/bootstrap.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/lisp2dot.js',
            '${root}plugins/visualizations/nlp_brat/static/js/xslt.js',
            '${root}plugins/visualizations/nlp_brat/static/js/viz.js',
            '${root}plugins/visualizations/nlp_brat/static/js/clearnlp_demo.js'
        );
        var webFontURLs = [
            '${root}plugins/visualizations/nlp_brat/static/fonts/Astloch-Bold.ttf',
            '${root}plugins/visualizations/nlp_brat/static/fonts/PT_Sans-Caption-Web-Regular.ttf',
            '${root}plugins/visualizations/nlp_brat/static/fonts/Liberation_Sans-Regular.ttf'
        ];

        var getTextAreaValue = function (textareaId) {
            return $("#"+textareaId).val();
        }



    var renderDotDisplay = function(dotDisplayId, inputId) {
        var docData = getTextAreaValue(inputId);
        // When has parser result.
        if (docData.indexOf("~~~~") > 0) {
            var docJSON = jQuery.parseJSON(docData.trim());
            var lisp = docJSON.text.split("~~~~")[1];
            console.log(lisp);
            var dot = lisp2dot(lisp);
            var svg = Viz(dot, "svg");
            var dotDisplay = $('#' + dotDisplayId);
            dotDisplay.html("");
            dotDisplay.html(svg);
            dotDisplay.show();
        } else {
            var dotDisplay = $('#' + dotDisplayId);
            dotDisplay.html("");
            dotDisplay.hide();
        }
    }

        var docChangeHandler = function(liveDispatcher, textareaId){
            var docInput = getTextAreaValue(textareaId);
            var docJSON;
            try {
                docJSON = jQuery.parseJSON(docInput.trim());
            } catch (e) {
                console.error('invalid JSON Data:', e);
                return;
            }
            try {
                liveDispatcher.post('requestRenderData', [$.extend({}, docJSON)]);
                console.info("docChangeHandler");
            } catch(e) {
                console.error('requestRenderData went down with:', e);
            }
        }


        var confChangeHandler = function(liveDispatcher, textareaId) {
            var collInput = getTextAreaValue(textareaId);
            var collJSON;
            try {
                collJSON = jQuery.parseJSON(collInput.trim());
            } catch (e) {
                console.error('invalid JSON Data:', e);
                return;
            }
            try {
                liveDispatcher.post('collectionLoaded',
                        [$.extend({'collection': null}, collJSON)]);
                console.info("confChangeHandler");
            } catch(e) {
                console.error('collectionLoaded went down with:', e);
            }
        }

        var listenTo = 'propertychange keyup input paste change';
        var onchange = function(textareaId, handler) {
            $("#"+textareaId).bind(listenTo, handler);
        }

        var renderBratDisplay =  function (displayId, inputId, confInputId, dotDisplayId) {
            var docData = getTextAreaValue(inputId);
            var collData = getTextAreaValue(confInputId);
            // Time for some "real" brat coding, let's hook into the dispatcher
            var liveDispatcher;
            try{
                liveDispatcher = Util.embed(displayId,
                    $.extend({'collection': null}, jQuery.parseJSON(collData.trim())),
                    $.extend({}, jQuery.parseJSON(docData.trim())), webFontURLs);
                console.info("Finished: liveDispatch");
            }catch(e) {
                console.error("ERROR: "+e+" ;doc="+docData+"; coll="+collData);
            }
            var renderError = function() {
                // setting this blows the layout (error --> red)
                $('#' + displayId).css({'border': '2px solid red'});
            };
            liveDispatcher.on('renderError: Fatal', renderError);

            onchange(inputId, function() {
                docChangeHandler(liveDispatcher, inputId);
                renderDotDisplay(dotDisplayId, inputId);
            });

            onchange(confInputId, function() {
                confChangeHandler(liveDispatcher, confInputId);
            });

            // packJSON used to make json neat and pack.
            var packJSON = function(s) {
                // replace any space with ' ' in non-nested curly brackets
                s = s.replace(/(\{[^\{\}\[\]]*\})/g,
                              function(a, b) { return b.replace(/\s+/g, ' '); });
                // replace any space with ' ' in [] up to nesting depth 1
                s = s.replace(/(\[(?:[^\[\]\{\}]|\[[^\[\]\{\}]*\])*\])/g,
                              function(a, b) { return b.replace(/\s+/g, ' '); });
                return s
            }
            // when input doc data changed
            // liveDispatcher.post('requestRenderData', [$.extend({}, jQuery.parseJSON(docInput.val()))]);

            // when config input coll data changed
            // liveDispatcher.post('collectionLoaded',  [$.extend({'collection': null}, jQuery.parseJSON(collInput.val()))]);
        }
        head.ready(function() {
            renderBratDisplay("instantbratdisplay", "docjson", "colljson", "instantdotdisplay");
        });
    </script>
    <style type="text/css">
        #instantdotdisplay {
            display:none;
            width:800px;
            height:400px;
            overflow:scroll;
        }
        #instantdotdisplay svg {
            width: auto;
            height: auto;
            border: 1px solid #7fa2ff;
            font-size: 15px;
        }
    </style>
</head>


## ----------------------------------------------------------------------------
<body>
<h2  align="center">Online Visualization of LappsGrid</h2>
<p style="text-align:center;font-size: 12pt;">
    LappsGrid, <var>Version 0.3.0</var>,  May 2015</p>

    <table align="center" class="table table-bordered table-striped responsive-utilities" align="center" style="width:800px;">
        <tr><th> Brat Display </th></tr>
        <tr><td height="100px"><div id="instantbratdisplay"></div></td></tr>
        <tr><td><div id="instantdotdisplay"></div></td></tr>
    </table>
    <textarea style="display:none" id="docjson">${bratjson}</textarea>
    <textarea style="display:none" id="colljson">${bratconf}</textarea>

    <!--<textarea>${hda}</textarea>-->
    <!--<textarea>${hda.datatype}</textarea>-->
    <!--<textarea>${hda.get_raw_data()}</textarea>-->
    <!--<textarea>${hda.name}</textarea>-->
    <!--<textarea>${hda.dataset}</textarea>-->
    <!--<textarea>${hda.dataset.file_name}</textarea>-->
    <!--<textarea>${hda.dataset.object_store}</textarea>-->
    <!--<textarea>${hda.dataset.object_store.config}</textarea>-->
    <!--<textarea>${json2jsonin}</textarea>-->
    <!--<textarea>${bratjson}</textarea>-->
    <!--<textarea>${json2jsonexp}</textarea>-->
    <!--<textarea>${lsjson2json}</textarea>-->

<footer>
    <hr />
    <p style="text-align:center">
        Contacts:
        <br/>&nbsp; &nbsp; <a target="_blank" class="nolink" href="http://www.cs.brandeis.edu/~jamesp/"> James Pustejovsky</a>
        (<nonsense>jame</nonsense>sp@<nonsense>cs.</nonsense>brandeis.<nonsense></nonsense>edu)
    </p>
</footer>
<p style="text-align:center">Copyright &copy; 2015 Lapps Grid - All Rights Reserved</p>
</body>
</html>
