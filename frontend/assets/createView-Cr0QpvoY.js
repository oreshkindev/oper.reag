import{d as x,c as v,b as n,a,w as u,o as w,f as b,u as t,j as U,_ as g}from"./index-C5oIhCp2.js";import{C}from"./ComponentButton-C3DWQZP6.js";import{C as k}from"./ComponentCard-B5uTf3KQ.js";import{C as s}from"./ComponentDropdownList-DHtqBo0Q.js";import{C as q}from"./ComponentHeading-DLXMcofr.js";import{_ as m}from"./ComponentInput.vue_vue_type_script_setup_true_lang-DhjdNZVI.js";import{u as S}from"./index-DfgwWP2A.js";import{u as y}from"./index-BoaXHYdk.js";import{u as _}from"./index-bABCztx_.js";import{u as B}from"./index-AcSQV57y.js";import"./index-DSbkomb1.js";const T=x({__name:"createView",setup($){const r=S(),i=y(),o=B(),d=_();return o.element={equipment_categories_id:0,http:"",ip:"",model:"",name:"",racks_id:0,serial_number:"",ssh:"",warranties_id:0,rtsp:""},r.fetchAll(),i.fetchAll(),d.fetchAll(),(A,e)=>(w(),v("main",null,[n("nav",null,[a(C,{to:{name:"equipment"}},{default:u(()=>e[11]||(e[11]=[b("Назад")])),_:1})]),a(q,null,{default:u(()=>e[12]||(e[12]=[n("h1",null,"Новая запись",-1),n("p",null," Lorem ipsum dolor sit amet consectetur, adipisicing elit. Quae aperiam facere consequuntur reiciendis dolorem unde eos porro cumque in assumenda voluptatum veniam nulla, ipsam magnam quaerat consequatur voluptas, eum perspiciatis? ",-1)])),_:1}),a(k,{tag:"section"},{default:u(()=>{var p,V,f;return[n("form",{onSubmit:e[10]||(e[10]=U(()=>{},["prevent"]))},[a(m,{type:"text",label:"Наименование",modelValue:t(o).element.name,"onUpdate:modelValue":e[0]||(e[0]=l=>t(o).element.name=l)},null,8,["modelValue"]),a(s,{label:"Категория",options:(p=t(r).elements)==null?void 0:p.map(l=>({value:l.id,label:l.name})),modelValue:t(o).element.equipment_categories_id,"onUpdate:modelValue":e[1]||(e[1]=l=>t(o).element.equipment_categories_id=l)},null,8,["options","modelValue"]),a(m,{type:"text",label:"Серийный номер",modelValue:t(o).element.serial_number,"onUpdate:modelValue":e[2]||(e[2]=l=>t(o).element.serial_number=l)},null,8,["modelValue"]),a(m,{type:"text",label:"Модель",modelValue:t(o).element.model,"onUpdate:modelValue":e[3]||(e[3]=l=>t(o).element.model=l)},null,8,["modelValue"]),a(m,{type:"text",label:"HTTP",modelValue:t(o).element.http,"onUpdate:modelValue":e[4]||(e[4]=l=>t(o).element.http=l)},null,8,["modelValue"]),a(m,{type:"text",label:"SSH",modelValue:t(o).element.ssh,"onUpdate:modelValue":e[5]||(e[5]=l=>t(o).element.ssh=l)},null,8,["modelValue"]),a(m,{type:"text",label:"IP",modelValue:t(o).element.ip,"onUpdate:modelValue":e[6]||(e[6]=l=>t(o).element.ip=l)},null,8,["modelValue"]),a(s,{label:"Телеком. шкаф",options:(V=t(i).elements)==null?void 0:V.map(l=>({value:l.id,label:l.name})),modelValue:t(o).element.racks_id,"onUpdate:modelValue":e[7]||(e[7]=l=>t(o).element.racks_id=l)},null,8,["options","modelValue"]),a(s,{label:"Гарантия",options:(f=t(d).elements)==null?void 0:f.map(l=>({value:l.id,label:l.name})),modelValue:t(o).element.warranties_id,"onUpdate:modelValue":e[8]||(e[8]=l=>t(o).element.warranties_id=l)},null,8,["options","modelValue"]),a(m,{type:"text",label:"RTSP",modelValue:t(o).element.rtsp,"onUpdate:modelValue":e[9]||(e[9]=l=>t(o).element.rtsp=l)},null,8,["modelValue"]),a(C,{onClick:t(o).save},{default:u(()=>e[13]||(e[13]=[b("Сохранить")])),_:1},8,["onClick"])],32)]}),_:1})]))}}),z=g(T,[["__scopeId","data-v-d72d7a43"]]);export{z as default};
