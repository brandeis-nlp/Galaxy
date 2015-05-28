<!DOCTYPE HTML>
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
</body>
