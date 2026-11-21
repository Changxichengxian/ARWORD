"""Bake three calibrated views of the hair to a single mobile material."""
from pathlib import Path
import bpy
from projection import project_hair

def bake(obj):
    data=obj.data
    view_kind=[v.value for v in data.attributes["Paint view"].data]
    artwork_uv=[(0,0)]*len(data.vertices)
    original=data.uv_layers.get("Illustration")
    for loop in data.loops:
        artwork_uv[loop.vertex_index]=tuple(original.data[loop.index].uv)
    data.materials.clear()
    mat=bpy.data.materials.new("Three-view projection")
    mat.use_nodes=True
    data.materials.append(mat)
    for poly in data.polygons:poly.material_index=0
    uv=data.uv_layers.new(name="Paint atlas")
    data.uv_layers.active=uv
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.12,island_margin=.009)
    bpy.ops.object.mode_set(mode="OBJECT")
    # After edit mode Blender recreates RNA wrappers for mesh layers.
    projections=[project_hair(*v.co) for v in data.vertices]
    for i,(front,side,back,weights) in enumerate(projections):
        wf,ws,wb=weights
        if view_kind[i]==2:
            front=artwork_uv[i]
            wf,ws,wb=.90,.10,0.
        elif view_kind[i]==3:
            back=artwork_uv[i]
        if view_kind[i]==1:
            front=artwork_uv[i]
            # Keep the central part and bangs registered with the eyes.
            # Allow the side projector to take over beyond the temples.
            y=data.vertices[i].co.y
            frontal=max(0.,min(1.,(-y-.025)/.17))
            wf+=frontal*(1.-wf)
            ws*=1.-frontal
            wb*=1.-frontal
        projections[i]=(front,side,back,(wf,ws,wb))
    data.attributes.remove(data.attributes["Paint view"])
    graph=mat.node_tree
    nodes=graph.nodes
    links=graph.links
    colors=data.color_attributes.new(name="Camera weights",type="FLOAT_COLOR",domain="POINT")
    weights=nodes.new("ShaderNodeVertexColor")
    weights.layer_name=colors.name
    separate=nodes.new("ShaderNodeSeparateXYZ")
    links.new(weights.outputs["Color"],separate.inputs[0])
    for i,q in enumerate(projections):
        colors.data[i].color=(*q[3],1)
    result=None
    for axis,name in enumerate(("front","side","back")):
        ref=data.uv_layers.new(name=name)
        for loop in data.loops:
            ref.data[loop.index].uv=projections[loop.vertex_index][axis]
        coords=nodes.new("ShaderNodeUVMap")
        coords.uv_map=name
        tex=nodes.new("ShaderNodeTexImage")
        source=Path(__file__).resolve().parents[2]/"art-source"/"whale-girl-paint"/(name+"-hair.png")
        tex.image=bpy.data.images.load(str(source),check_existing=True)
        tex.extension="EXTEND"
        links.new(coords.outputs[0],tex.inputs["Vector"])
        weighted=nodes.new("ShaderNodeVectorMath")
        weighted.operation="SCALE"
        links.new(tex.outputs["Color"],weighted.inputs[0])
        links.new(separate.outputs[axis],weighted.inputs["Scale"])
        if result is None:
            result=weighted.outputs[0]
        else:
            add=nodes.new("ShaderNodeVectorMath")
            add.operation="ADD"
            links.new(result,add.inputs[0])
            links.new(weighted.outputs[0],add.inputs[1])
            result=add.outputs[0]
    emit=nodes.new("ShaderNodeEmission")
    links.new(result,emit.inputs[0])
    links.new(emit.outputs[0],nodes.get("Material Output").inputs["Surface"])
    im=bpy.data.images.new("Whale hair painted atlas",1536,1536,alpha=False)
    target=nodes.new("ShaderNodeTexImage")
    target.image=im
    nodes.active=target
    data.uv_layers.active=data.uv_layers["Paint atlas"]
    data.uv_layers.active.active_render=True
    sc=bpy.context.scene
    sc.render.engine="CYCLES"
    sc.cycles.samples=1
    bpy.ops.object.bake(type="EMIT",margin=10,uv_layer="Paint atlas")
    im.pack()
    for old in list(data.uv_layers.keys()):
        if old!="Paint atlas":data.uv_layers.remove(data.uv_layers[old])
    data.color_attributes.remove(data.color_attributes["Camera weights"])
    mat=bpy.data.materials.new("Indigo silk and glacier blue")
    mat.use_nodes=True
    mat.use_backface_culling=False
    data.materials[0]=mat
    bs=mat.node_tree.nodes.get("Principled BSDF")
    tex=mat.node_tree.nodes.new("ShaderNodeTexImage");tex.image=im
    mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Base Color"])
    mat.node_tree.links.new(tex.outputs["Color"],bs.inputs["Emission Color"])
    bs.inputs["Emission Strength"].default_value=.12
    bs.inputs["Roughness"].default_value=.84
    bs.inputs["Specular IOR Level"].default_value=.1
    # Keep the painted fringe and the thin, curling outer locks at their
    # original texel density. Repacking slender tips into the atlas blurs
    # the ink and samples the wall of the neighbouring lock at a distance.
    source_uv=data.uv_layers["Paint atlas"]
    original_mat=mat.copy()
    original_mat.name="Indigo silk and glacier blue - fine front ink"
    graph=original_mat.node_tree
    texture=next(n for n in graph.nodes if n.type=="TEX_IMAGE")
    texture.image=bpy.data.images["front-hair.png"]
    data.materials.append(original_mat)
    for poly in data.polygons:
        index=poly.vertices[0]
        if view_kind[index]==2:
            poly.material_index=1
            for lid in poly.loop_indices:
                source_uv.data[lid].uv=artwork_uv[data.loops[lid].vertex_index]
