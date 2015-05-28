<!DOCTYPE HTML>

<%
bratdsl = """
{
def idx = 0
def lastview = &$payload.views[-1]
def lastviewanns = lastview==null?null:lastview.annotations
def lastviewfeatures = lastviewanns==null?null:lastviewanns.features
def parse = lastviewfeatures == null? null:lastviewfeatures.penntree
def coref = lastviewanns.select{&."@type"=="http://vocab.lappsgrid.org/Coreference"}.features.mentions
def markables = lastviewanns.select{&."@type"=="http://vocab.lappsgrid.org/Markable" && coref.toString().contains(&.id)}

text &$payload.text."@value" + (parse == null?"":parse)

relations (lastviewanns.select{&."@type"=="http://vocab.lappsgrid.org/DependencyStructure"}.features.dependencies
.flatten().foreach{
["D${idx++}", &.label, [["Governor", &.features.governor], ["Dependent", &.features.dependent]]]
})

equivs (lastviewanns.select{&."@type"=="http://vocab.lappsgrid.org/Coreference"}.features
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
%>

<html>
<head>

    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, user-scalable=no, minimum-scale=1.0, maximum-scale=1.0">

    <title>${hda.name} | ${visualization_name}</title>
<%
    root = h.url_for( '/' )
%>

${h.stylesheet_link( root + 'plugins/visualizations/nlp_brat/static/css/style-vis.css' )}
${h.javascript_link( root + 'plugins/visualizations/nlp_brat/static/js/head.load.min.js' )}




</head>

<%
def shellquote(s):
    return "'" + s.replace("'", "'\\''") + "'"
%>
<%
import commands;
lappsjson = hda.get_raw_data();
projhome = commands.getstatusoutput("pwd")[1]
lsdpath = projhome + '/config/plugins/visualizations/nlp_brat/json2json.lsd'
lsjson2json = commands.getstatusoutput("ls "+lsdpath)[1]
%>

<%
import os, json, subprocess, uuid;
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
bratjson = output.stdout.read()
json2jsonexp = output.stderr

os.remove(fil)
%>



## ----------------------------------------------------------------------------
<body>
    <script>
        head.js(
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.svg.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/jquery.svgdom.min.js',
            '${root}plugins/visualizations/nlp_brat/static/js/webfont.js',
            '${root}plugins/visualizations/nlp_brat/static/js/util.js',
            '${root}plugins/visualizations/nlp_brat/static/js/annotation_log.js',
            '${root}plugins/visualizations/nlp_brat/static/js/dispatcher.js',
            '${root}plugins/visualizations/nlp_brat/static/js/url_monitor.js',
            '${root}plugins/visualizations/nlp_brat/static/js/visualizer.js',
            '${root}plugins/visualizations/nlp_brat/static/js/configuration.js'
        );
        var webFontURLs = [
            '${root}plugins/visualizations/nlp_brat/static/fonts/Astloch-Bold.ttf',
            '${root}plugins/visualizations/nlp_brat/static/fonts/PT_Sans-Caption-Web-Regular.ttf',
            '${root}plugins/visualizations/nlp_brat/static/fonts/Liberation_Sans-Regular.ttf'
        ];
        var docData = {
            // Our text of choice
            text     : "Ed O'Kelley was the man who shot the man who shot Jesse James.",
            // The entities entry holds all entity annotations
            entities : [
                /* Format: [ID, TYPE, [[START, END]]]
                    note that range of the offsets are [START,END) */
                ['T1', 'Person', [[0, 11]]],
                ['T2', 'Person', [[20, 23]]],
                ['T3', 'Person', [[37, 40]]],
                ['T4', 'Person', [[50, 61]]],
            ],
            attributes: [["A1", "Notorious", "T1"]],
            relations: [
            	["R1", "Anaphora", [["Anaphor", "T2"], ["Entity", "T1"]]]
            ],
            triggers: [
            	[ "T5", "Assassination", [[ 45, 49 ]] ],
            	[ "T6", "Assassination", [[ 28, 32 ]] ]
            ],
			events: [
				[
					"E1",
					"T5",
					[ [ "Perpetrator", "T3" ], [ "Victim", "T4" ] ]
				],
				[
					"E2",
					"T6",
					[ [ "Perpetrator", "T2" ], [ "Victim", "T3" ] ]
				]
			]
            <%doc>
			</%doc>
		};
        var collData = {
            entity_types: [ {
                    type   : 'Person',
                    /* The labels are used when displaying the annotion, in this case
                        we also provide a short-hand "Per" for cases where
                        abbreviations are preferable */
                    labels : ['Person', 'Per'],
                    // Blue is a nice colour for a person?
                    bgColor: '#7fa2ff',
                    // Use a slightly darker version of the bgColor for the border
                    borderColor: 'darken'
            } ],
            entity_attribute_types: [{
            	type: "Notorious",
            	values: { Notorious: { glyph: "*" } },
            	bool: "Notorious"
            }],
            relation_types: [{
            	type: "Anaphora",
            	labels: ["Anaphora", "Ana"],
            	dashArray: "3,3",
            	color: "purple",
            	args: [
            		{
            			role:"Anaphor",
            			targets: ["Person"]
            		},
            		{
            			role:"Entity",
            			targets: ["Person"]
            		}
            	]
            }],
			event_types: [{
				type: "Assassination",
				labels: [ "Assassination", "Assas" ],
				bgColor: "lightgreen",
				borderColor: "darken",
				arc: [
					{
						type: "Victim",
						labels: [ "Victim", "Vict" ]
					},
					{
						type: "Perpetrator",
						labels: [ "Perpetrator", "Perp" ],
						color: "green"
					}
				]
			}]
            <%doc>
			</%doc>
        };
        head.ready(function() {
            Util.embed(
                // id of the div element where brat should embed the visualisations
                'brat_vis',
                // object containing collection data
                collData,
                // object containing document data
                docData,
                // Array containing locations of the visualisation fonts
                webFontURLs
                );
        });
    </script>
    <div id="brat_vis"></div>
    <textarea>${hda}</textarea>
    <textarea>${hda.datatype}</textarea>
    <textarea>${hda.get_raw_data()}</textarea>
    <textarea>${hda.name}</textarea>
    <textarea>${hda.dataset}</textarea>
    <textarea>${hda.dataset.file_name}</textarea>
    <textarea>${hda.dataset.object_store}</textarea>
    <textarea>${hda.dataset.object_store.config}</textarea>
    <textarea>${json2jsonin}</textarea>
    <textarea>${bratjson}</textarea>
    <textarea>${json2jsonexp}</textarea>
    <textarea>${lsjson2json}</textarea>
</body>
