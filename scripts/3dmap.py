import sys
import pydeck as pdk
import geopandas as gpd

import matplotlib.colors as colors
import matplotlib.cm as cmx
import matplotlib.pyplot as plt

if len(sys.argv) < 2:
    print('please, set geojson with hexegons')

geojson = sys.argv[1]
outfile = sys.argv[2]

def set_color(mag):
    if mag == 5:
        return (1.0, 0.8196078431372549, 0.011764705882352941, 1.0)
    elif mag == 5.1:
        return (0.996078431372549, 0.7764705882352941, 0.12941176470588237, 1.0)
    elif mag == 5.2:
        return (0.996078431372549, 0.7333333333333333, 0.24705882352941178, 1.0)
    elif mag == 6:
        return (0.9921568627450981, 0.6901960784313725, 0.3607843137254902, 1.0)
    elif mag == 7:
        return (0.9490196078431372, 0.5098039215686274, 0.30196078431372547, 1.0)
    elif mag == 8:
        return (0.8941176470588236, 0.30196078431372547, 0.20392156862745098, 1.0)
    else:
        return (1.0, 0.8196078431372549, 0.011764705882352941, 1.0)

def main(file):
    print (geojson)
    print (outfile)
    # read file as geopandas dataframe
    gdf = gpd.read_file(file)

    print('----')
    # drop geometry
    df = gdf[["h3idx", "value", "population","units", "lon", "lat"]]

    # setup default view box 
    view = pdk.data_utils.compute_view(df[["lon", "lat"]])
    view.pitch = 75

    # create mapping from population to color
    plasma = cm = plt.get_cmap('YlOrBr') 
    cNorm  = colors.Normalize(vmin=df["population"].min(), vmax=df["population"].max())
    scalarMap = cmx.ScalarMappable(norm=cNorm, cmap=plasma)
    # df["color"] = df.apply (lambda row: scalarMap.to_rgba(row["population"]), axis=1)
    df["color"] = df.apply (lambda row: set_color(row["value"]), axis=1)

    # create column layer in pydeck
    column_layer = pdk.Layer(
        "ColumnLayer",
        data=df,
        get_position=["lon", "lat"],
        get_elevation="population",
        elevation_scale=4,
        radius=450,
        pickable=True,
        get_fill_color="[color[0] * 255, color[1] * 255, color[2] * 255, color[3] * 255]",
        auto_highlight=True,
    )

    # add tooltip 
    tooltip = {
        "html": "<b>{population}</b> people in {h3idx}, value - {value} {units}",
        "style": {"background": "white", "color": "gray", "font-family": '"Helvetica Neue", Arial', "z-index": "10000"},
    }

    r = pdk.Deck(
        column_layer,
        initial_view_state=view,
        tooltip=tooltip
    )

    r.to_html(outfile, notebook_display=True)

if __name__ == '__main__':
    main(geojson)
