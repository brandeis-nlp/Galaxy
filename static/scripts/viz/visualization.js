/**
 * Model, view, and controller objects for Galaxy tools and tool panel.
 *
 * Models have no references to views, instead using events to indicate state 
 * changes; this is advantageous because multiple views can use the same object 
 * and models can be used without views.
 */
 
// --------- Models ---------

/**
 * Generic cache that handles key/value pairs.
 */ 
var Cache = Backbone.Model.extend({
    defaults: {
        num_elements: 20,
        obj_cache: {},
        key_ary: []
    },
    
    get_elt: function(key) {
        var obj_cache = this.attributes.obj_cache,
            key_ary = this.attributes.key_ary,
            index = key_ary.indexOf(key);
        if (index !== -1) {
            if (obj_cache[key].stale) {
                // Object is stale, so remove key and object.
                key_ary.splice(index, 1);
                delete obj_cache[key];
            }
            else {
                this.move_key_to_end(key, index);
            }
        }
        return obj_cache[key];
    },
    
    set_elt: function(key, value) {
        var obj_cache = this.attributes.obj_cache,
            key_ary = this.attributes.key_ary,
            num_elements = this.attributes.num_elements;
        if (!obj_cache[key]) {
            if (key_ary.length >= num_elements) {
                // Remove first element
                var deleted_key = key_ary.shift();
                delete obj_cache[deleted_key];
            }
            key_ary.push(key);
        }
        obj_cache[key] = value;
        return value;
    },
    
    // Move key to end of cache. Keys are removed from the front, so moving a key to the end 
    // delays the key's removal.
    move_key_to_end: function(key, index) {
        this.attributes.key_ary.splice(index, 1);
        this.attributes.key_ary.push(key);
    },
    
    clear: function() {
        this.attributes.obj_cache = {};
        this.attributes.key_ary = [];
    },
    
    // Returns the number of elements in the cache.
    size: function() {
        return this.attributes.key_ary.length;
    }
});

/**
 * Data manager for genomic data. Data is connected to and queryable by genomic regions.
 */
var GenomeDataManager = Cache.extend({
    defaults: _.extend({}, Cache.prototype.defaults, {
        dataset: null,
        filters_manager: null,
        data_url: null,
        data_mode_compatible: function(entry, mode) { return true; },
        can_subset: function(entry) { return false; }
    }),
    
    /**
     * Load data from server; returns AJAX object so that use of Deferred is possible.
     */
    load_data: function(region, mode, resolution, extra_params) {
        // Setup data request params.
        var params = {
                        "chrom": region.get('chrom'), 
                        "low": region.get('start'), 
                        "high": region.get('end'), 
                        "mode": mode, 
                        "resolution": resolution
                     };
            dataset = this.get('dataset');
                        
        // ReferenceDataManager does not have dataset.
        if (dataset) {
            params['dataset_id'] = dataset.id;
            params['hda_ldda'] = dataset.get('hda_ldda');
        }
        
        $.extend(params, extra_params);
        
        // Add track filters to params.
        var filters_manager = this.get('filters_manager');
        if (filters_manager) {
            var filter_names = [];
            var filters = filters_manager.filters;
            for (var i = 0; i < filters.length; i++) {
                filter_names.push(filters[i].name);
            }
            params.filter_cols = JSON.stringify(filter_names);
        }
                        
        // Do request.
        var manager = this;
        return $.getJSON(this.get('data_url'), params, function (result) {
            manager.set_data(region, result);
        });
    },
    
    /**
     * Get data from dataset.
     */
    get_data: function(region, mode, resolution, extra_params) {
        // Debugging:
        //console.log("get_data", low, high, mode);
        /*
        console.log("cache contents:")
        for (var i = 0; i < this.key_ary.length; i++) {
            console.log("\t", this.key_ary[i], this.obj_cache[this.key_ary[i]]);
        }
        */
                
        // Look for entry and return if it's a deferred or if data available is compatible with mode.
        var entry = this.get_elt(region);
        if ( entry && 
             ( is_deferred(entry) || this.get('data_mode_compatible')(entry, mode) ) ) {
            return entry;
        }

        //
        // Look in cache for data that can be used. Data can be reused if it
        // has the requested data and is not summary tree and has details.
        // TODO: this logic could be improved if the visualization knew whether
        // the data was "index" or "data."
        //
        var 
            key_ary = this.get('key_ary'),
            obj_cache = this.get('obj_cache'),
            key, region, entry_region, mode, entry;
        for (var i = 0; i < key_ary.length; i++) {
            entry_region = new GenomeRegion(key_ary[i]);
        
            if (entry_region.contains(region)) {
                // This entry has data in the requested range. Return if data
                // is compatible and can be subsetted.
                var entry = obj_cache[key];
                if ( is_deferred(entry) || 
                    ( this.get('data_mode_compatible')(entry, mode) && this.get('can_subset')(entry) ) ) {
                    this.move_key_to_end(key, i);
                    return entry;
                }
            }
        }
                
        // Load data from server. The deferred is immediately saved until the
        // data is ready, it then replaces itself with the actual data.
        entry = this.load_data(region, mode, resolution, extra_params);
        this.set_data(region, entry);
        return entry;
    },
    
    /**
     * Alias for set_elt for readbility.
     */
    set_data: function(region, entry) {
        this.set_elt(region, entry);  
    },
    
    /**
    
    /** "Deep" data request; used as a parameter for DataManager.get_more_data() */
    DEEP_DATA_REQ: "deep",
    
    /** "Broad" data request; used as a parameter for DataManager.get_more_data() */
    BROAD_DATA_REQ: "breadth",
    
    /**
     * Gets more data for a region using either a depth-first or a breadth-first approach.
     */
    get_more_data: function(region, mode, resolution, extra_params, req_type) {
        //
        // Get current data from cache and mark as stale.
        //
        var cur_data = this.get_elt(region);
        if ( !(cur_data && this.get('data_mode_compatible')(cur_data, mode)) ) {
            console.log("ERROR: no current data for: ", dataset, region.toString(), mode, resolution, extra_params);
            return;
        }
        cur_data.stale = true;
        
        //
        // Set parameters based on request type.
        //
        var query_low = region.get('start');
        if (req_type === this.DEEP_DATA_REQ) {
            // Use same interval but set start_val to skip data that's already in cur_data.
            $.extend(extra_params, {start_val: cur_data.data.length + 1});
        }
        else if (req_type === this.BROAD_DATA_REQ) {
            // To get past an area of extreme feature depth, set query low to be after either
            // (a) the maximum high or HACK/FIXME (b) the end of the last feature returned.
            query_low = (cur_data.max_high ? cur_data.max_high : cur_data.data[cur_data.data.length - 1][2]) + 1;
        }
        var query_region = region.copy().set('start', query_low);
        
        //
        // Get additional data, append to current data, and set new data. Use a custom deferred object
        // to signal when new data is available.
        //
        var 
            data_manager = this,
            new_data_request = this.load_data(query_region, mode, resolution, extra_params)
            new_data_available = $.Deferred();
        // load_data sets cache to new_data_request, but use custom deferred object so that signal and data
        // is all data, not just new data.
        this.set_data(region, new_data_available);
        $.when(new_data_request).then(function(result) {
            // Update data and message.
            if (result.data) {
                result.data = cur_data.data.concat(result.data);
                if (result.max_low) {
                    result.max_low = cur_data.max_low;
                }
                if (result.message) {
                    // HACK: replace number in message with current data length. Works but is ugly.
                    result.message = result.message.replace(/[0-9]+/, result.data.length);
                }
            }
            data_manager.set_data(region, result);
            new_data_available.resolve(result);
        });
        return new_data_available;
    },
        
    /**
     * Get data from the cache.
     */
    get_elt: function(region) {
        return Cache.prototype.get_elt.call(this, region.toString());
    },
    
    /**
     * Sets data in the cache.
     */
    set_elt: function(region, result) {
        return Cache.prototype.set_elt.call(this, region.toString(), result);
    }
});

var ReferenceTrackDataManager = GenomeDataManager.extend({
    load_data: function(low, high, mode, resolution, extra_params) {
        if (resolution > 1) {
            // Now that data is pre-fetched before draw, we don't load reference tracks
            // unless it's at the bottom level.
            return { data: null };
        }
        return GenomeDataManager.prototype.load_data.call(this, low, high, mode, resolution, extra_params);
    } 
});
 
/**
 * A genome build.
 */
var Genome = Backbone.Model.extend({
    defaults: {
        name: null,
        key: null,
        chroms_info: null
    },
    
    get_chroms_info: function() {
        return this.attributes.chroms_info.chrom_info;  
    }
});

/**
 * A genomic region.
 */
var GenomeRegion = Backbone.Model.extend({
    defaults: {
        chrom: null,
        start: 0,
        end: 0,
        DIF_CHROMS: 1000,
        BEFORE: 1001, 
        CONTAINS: 1002, 
        OVERLAP_START: 1003, 
        OVERLAP_END: 1004, 
        CONTAINED_BY: 1005, 
        AFTER: 1006
    },
    
    /**
     * as_str attribute using the format chrom:start-end can be 
     * used to set object's attributes.
     */
    initialize: function(options) {
        if (!this.get('chrom') && !this.get('start') && 
            !this.get('end') && 'as_str' in options) {
            var pieces = options.as_str.split(':'),
                chrom = pieces[0],
                pieces = pieces.split('-'),
                start = pieces[0],
                end = pieces[1];
            this.set('chrom', chrom);
            this.set('start', start);
            this.set('end', end);
        }  
    },
    
    copy: function() {
        return new GenomeRegion({
            chrom: this.get('chrom'),
            start: this.get('start'),
            end: this.get('end') 
        });
    },
    
    /** Returns region in canonical form chrom:start-end */
    toString: function() {
        return this.get('chrom') + ":" + this.get('start') + "-" + this.get('end');
    },
    
    /**
     * Compute the type of overlap between this region and another region. The overlap is computed relative to the given/second region; 
     * hence, OVERLAP_START indicates that the first region overlaps the start (but not the end) of the second region.
     */
    compute_overlap: function(a_region) {
        var first_chrom = this.get('chrom'), second_chrom = a_region.get('chrom'),
            first_start = this.get('start'), second_start = a_region.get('start'),
            first_end = this.get('end'), second_end = a_region.get('end'),
            overlap;
            
        // Look at chroms.
        if (first_chrom && second_chrom && first_chrom !== second_chrom) {
            return this.get('DIF_CHROMS');
        }
        
        // Look at regions.
        if (first_start < second_start) {
            if (first_end < second_start) {
                overlap = this.get('BEFORE');
            }
            else if (first_end <= second_end) {
                overlap = this.get('OVERLAP_START');
            }
            else { // first_end > second_end
                overlap = this.get('CONTAINS');
            }
        }
        else { // first_start >= second_start
            if (first_start > second_end) {
                overlap = this.get('AFTER');
            }
            else if (first_end <= second_end) {
                overlap = this.get('CONTAINED_BY');
            }
            else {
                overlap = this.get('OVERLAP_END');
            }
        }

        return overlap;
    },
    
    /**
     * Returns true if this region contains a given region.
     */
    contains: function(a_region) {
        return this.compute_overlap(a_region) === this.get('CONTAINS');  
    },

    /**
     * Returns true if regions overlap.
     */
    overlaps: function(a_region) {
        return _.intersection( [this.compute_overlap(a_region)], 
                               [this.get('DIF_CHROMS'), this.get('BEFORE'), this.get('AFTER')] ).length === 0;  
    }
});

/**
 * A genome browser bookmark.
 */
var BrowserBookmark = Backbone.Model.extend({
    defaults: {
        region: null,
        note: ""
    }
});

/**
 * Bookmarks collection.
 */
var BrowserBookmarks = Backbone.Collection.extend({
    model: BrowserBookmark
});

/**
 * A visualization.
 */
var Visualization = Backbone.RelationalModel.extend({
    defaults: {
        id: "",
        title: "",
        type: "",
        dbkey: "",
        datasets: []
    },
    
    url: function() { return galaxy_paths.get("visualization_url"); },
    
    /**
     * POSTs visualization's JSON to its URL using the parameter 'vis_json'
     * Note: This is necessary because (a) Galaxy requires keyword args and 
     * (b) Galaxy does not handle PUT now.
     */
    save: function() {
        return $.ajax({
            url: this.url(),
            type: "POST",
            dataType: "json",
            data: { 
                vis_json: JSON.stringify(this)
            }
        });
    }
});

/**
 * A Trackster visualization.
 */
var TracksterVisualization = Visualization.extend({
    defaults: {
        bookmarks: [],
        viewport: {}
    }
});

/**
 * A Circster visualization.
 */
var CircsterVisualization = Visualization.extend({
});

/**
 * A dataset. In Galaxy, datasets are associated with a history, so
 * this object is also known as a HistoryDatasetAssociation.
 */
var Dataset = Backbone.Model.extend({
    defaults: {
        id: "",
        type: "",
        name: "",
        hda_ldda: ""
    } 
});

/**
 * A histogram dataset.
 */
var HistogramDataset = Backbone.Model.extend({
    /*
    defaults: {
        data: [],
        dataset: null,
        max: 0  
    },
    */
    
    initialize: function(data) {
        // Set max across dataset.
        this.attributes.data = data;
        this.attributes.max = _.max(data, function(d) { 
            if (!d || typeof d === "string") { return 0; }
            return d[1];
        })[1];
    }
    
});

/**
 * Configuration data for a Trackster track.
 */
var TrackConfig = Backbone.Model.extend({
    
});

/**
 * Layout for a histogram dataset in a circster visualization.
 */
var CircsterHistogramDatasetLayout = Backbone.Model.extend({
    // TODO: should accept genome and dataset and use these to generate layout data.
    
    /**
     * Returns arc layouts for genome's chromosomes/contigs. Arcs are arranged in a circle 
     * separated by gaps.
     */
    chroms_layout: function() {
        // Setup chroms layout using pie.
        var chroms_info = this.attributes.genome.get_chroms_info(),
            pie_layout = d3.layout.pie().value(function(d) { return d.len; }).sort(null),
            init_arcs = pie_layout(chroms_info),
            gap_per_chrom = this.attributes.total_gap / chroms_info.length,
            chrom_arcs = _.map(init_arcs, function(arc, index) {
                // For short chroms, endAngle === startAngle.
                var new_endAngle = arc.endAngle - gap_per_chrom;
                arc.endAngle = (new_endAngle > arc.startAngle ? new_endAngle : arc.startAngle);
                return arc;
            });
            
            // TODO: remove arcs for chroms that are too small and recompute?
            
        return chrom_arcs;
    },
    
    /**
     * Returns layouts for drawing a chromosome's data. For now, only works with summary tree data.
     */
    chrom_data_layout: function(chrom_arc, chrom_data, inner_radius, outer_radius, max) {             
        // If no chrom data, return null.
        if (!chrom_data || typeof chrom_data === "string") {
            return null;
        }
        
        var data = chrom_data[0],
            delta = chrom_data[3],
            scale = d3.scale.linear()
                .domain( [0, max] )
                .range( [inner_radius, outer_radius] ),                        
            arc_layout = d3.layout.pie().value(function(d) {
                return delta;
            })
                .startAngle(chrom_arc.startAngle)
                .endAngle(chrom_arc.endAngle),
        arcs = arc_layout(data);
        
        // Use scale to assign outer radius.
        _.each(data, function(datum, index) {
            arcs[index].outerRadius = scale(datum[1]);
        });
        
        return arcs;
    }
    
});
 
/**
 * -- Views --
 */
 
var CircsterView = Backbone.View.extend({
    className: 'circster',
    
    initialize: function(options) {
        this.width = options.width;
        this.height = options.height;
        this.total_gap = options.total_gap;
        this.genome = options.genome;
        this.dataset = options.dataset;
        this.radius_start = options.radius_start;
        this.dataset_arc_height = options.dataset_arc_height;
    },
    
    render: function() {
        // -- Layout viz. --
        
        var radius_start = this.radius_start,
            dataset_arc_height = this.dataset_arc_height,
            
            // Layout chromosome arcs.
            arcs_layout = new CircsterHistogramDatasetLayout({
                genome: this.genome,
                total_gap: this.total_gap
            }),
            chrom_arcs = arcs_layout.chroms_layout(),
            
            // Merge chroms layout with data.
            layout_and_data = _.zip(chrom_arcs, this.dataset.attributes.data),
            dataset_max = this.dataset.attributes.max,
            
            // Do dataset layout for each chromosome's data using pie layout.
            chroms_data_layout = _.map(layout_and_data, function(chrom_info) {
                var chrom_arc = chrom_info[0],
                    chrom_data = chrom_info[1];
                return arcs_layout.chrom_data_layout(chrom_arc, chrom_data, radius_start, radius_start + dataset_arc_height, dataset_max);
            });
        
        // -- Render viz. --
        
        var svg = d3.select(this.$el[0])
          .append("svg")
            .attr("width", this.width)
            .attr("height", this.height)
          .append("g")
            .attr("transform", "translate(" + this.width / 2 + "," + this.height / 2 + ")");

        // Draw background arcs for each chromosome.
        var base_arc = svg.append("g").attr("id", "inner-arc"),
            arc_gen = d3.svg.arc()
                .innerRadius(radius_start)
                .outerRadius(radius_start + dataset_arc_height),
            // Draw arcs.
            chroms_elts = base_arc.selectAll("#inner-arc>path")
                .data(chrom_arcs).enter().append("path")
                .attr("d", arc_gen)
                .style("stroke", "#ccc")
                .style("fill",  "#ccc")
                .append("title").text(function(d) { return d.data.chrom; });

        // For each chromosome, draw dataset.
        _.each(chroms_data_layout, function(chrom_layout) {
            if (!chrom_layout) { return; }

            var group = svg.append("g"),
                arc_gen = d3.svg.arc().innerRadius(radius_start),
                dataset_elts = group.selectAll("path")
                    .data(chrom_layout).enter().append("path")
                    .attr("d", arc_gen)
                    .style("stroke", "red")
                    .style("fill",  "red");
        });
    } 
});

/**
 * -- Routers --
 */

/**
 * Router for track browser.
 */
var TrackBrowserRouter = Backbone.Router.extend({    
    initialize: function(options) {
        this.view = options.view;
        
        // Can't put regular expression in routes dictionary.
        // NOTE: parentheses are used to denote parameters returned to callback.
        this.route(/([\w]+)$/, 'change_location');
        this.route(/([\w]+\:[\d,]+-[\d,]+)$/, 'change_location');
        
        // Handle navigate events from view.
        var self = this;
        self.view.on("navigate", function(new_loc) {
            self.navigate(new_loc);
        });
    },
    
    change_location: function(new_loc) {
        this.view.go_to(new_loc);
    }
});

/**
 * -- Helper functions.
 */
 
/**
 * Use a popup grid to add more datasets.
 */
var add_datasets = function(dataset_url, add_track_async_url, success_fn) {
    $.ajax({
        url: dataset_url,
        data: { "f-dbkey": view.dbkey },
        error: function() { alert( "Grid failed" ); },
        success: function(table_html) {
            show_modal(
                "Select datasets for new tracks",
                table_html, {
                    "Cancel": function() {
                        hide_modal();
                    },
                    "Add": function() {
                        var requests = [];
                        $('input[name=id]:checked,input[name=ldda_ids]:checked').each(function() {
                            var data,
                                id = $(this).val();
                                if ($(this).attr("name") === "id") {
                                    data = { hda_id: id };
                                } else {
                                    data = { ldda_id: id};
                                }
                                requests[requests.length] = $.ajax({
                                    url: add_track_async_url,
                                    data: data,
                                    dataType: "json",
                                });
                        });
                        // To preserve order, wait until there are definitions for all tracks and then add 
                        // them sequentially.
                        $.when.apply($, requests).then(function() {
                            // jQuery always returns an Array for arguments, so need to look at first element
                            // to determine whether multiple requests were made and consequently how to 
                            // map arguments to track definitions.
                            var track_defs = (arguments[0] instanceof Array ?  
                                               $.map(arguments, function(arg) { return arg[0]; }) :
                                               [ arguments[0] ]
                                               );
                            success_fn(track_defs);
                        });
                        hide_modal();
                    }
                }
            );
        }
    });
};