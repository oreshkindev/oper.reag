import{d as S,e as D,q as B,c as p,r as E,s as z,o as r,_ as U,b as u,t as H,v as C,i as L,u as n,F as P,j as V,x as q,y as A,a as w,w as M,z as R,f as W}from"./index-C5oIhCp2.js";import{C as X}from"./ComponentButton-C3DWQZP6.js";import{C as Y}from"./ComponentDropdownList-DHtqBo0Q.js";import{C as Z}from"./ComponentHeading-DLXMcofr.js";import{u as T,a as G,b as J}from"./useSchemeUtils-DA7HbfU5.js";import{u as F}from"./index-AcSQV57y.js";import{u as j}from"./index-B9ZK_c7E.js";import{u as K,C as O}from"./index-CdzkAxPu.js";import"./index-DSbkomb1.js";const Q=S({__name:"ComponentDialog",setup($,{expose:s}){const t=D(),m=l=>{if(t.value){const{clientX:v,clientY:_}=l;t.value.style.inset=`${_}px auto auto ${v}px`,t.value.show()}},d=()=>{t.value&&t.value.showModal()},y=()=>{t.value&&t.value.close()};return s({show:m,showModal:d,close:y}),(l,v)=>{const _=z("outside");return B((r(),p("dialog",{ref_key:"dialog",ref:t},[E(l.$slots,"default",{},void 0,!0)])),[[_,y]])}}}),N=U(Q,[["__scopeId","data-v-3a12c4dd"]]),ee=["x","y"],te=["x","y"],oe=S({__name:"ComponentTooltip",props:{text:{},x:{},y:{}},setup($){const s=$;return(t,m)=>(r(),p("g",null,[u("rect",{x:s.x-50,y:s.y+20,width:"100",height:"30",rx:"5"},null,8,ee),u("text",{x:s.x,y:s.y+40,"text-anchor":"middle"},H(t.text),9,te)]))}}),ne=U(oe,[["__scopeId","data-v-2e9abe2f"]]),se=["d","transform"],le=["cx","cy","r","onMouseenter"],ie=S({__name:"ComponentPoint",setup($){const s=T(),t=j(),m=F(),d=D(!0),{path:y,transform:l}=G(),v=a=>{s.element={...a}},_=C(()=>{var a;return(a=s.elements)==null?void 0:a.filter(c=>c.schemes_id===t.element.id&&c.equipment_categories_id===1)}),g=C(()=>m.elements.find(a=>a.id===s.element.id));return s.fetchAll(),(a,c)=>(r(!0),p(P,null,L(_.value,(i,b)=>{var h;return r(),p("g",{key:b},[u("path",{d:n(y)(i),transform:n(l)(i)},null,8,se),i.point_positions?(r(),p(P,{key:0},[u("circle",{cx:i.point_positions.x,cy:i.point_positions.y,r:i.point_positions.r,onMouseenter:V(()=>{v(i),d.value=!1},["stop"]),onMouseleave:c[0]||(c[0]=I=>d.value=!0)},null,40,le),!d.value&&((h=g.value)==null?void 0:h.id)===i.id?(r(),q(ne,{key:0,text:g.value.name,x:i.point_positions.x??0,y:i.point_positions.y??0},null,8,["text","x","y"])):A("",!0)],64)):A("",!0)])}),128))}}),re=U(ie,[["__scopeId","data-v-ce8572e5"]]),ae=["href"],ue=S({__name:"indexView",setup($){const s="http://192.168.111.254",t=D(),m=D(),d=K(),y=T(),l=j(),v=F(),{state:_,startDrag:g,drag:a,endDrag:c,zoom:i}=J(),b=C(()=>{const{x,y:e,scale:f}=_.value;return`translate(${x}px, ${e}px) scale(${f})`}),h=C(()=>{var x,e;return`${s}/in/${(e=(x=l.elements)==null?void 0:x.filter(f=>f.id===l.element.id)[0])==null?void 0:e.file}`}),I=C(()=>d.elements.filter(x=>{var e;return x.url===((e=v.elements.filter(f=>f.id===y.element.id)[0])==null?void 0:e.rtsp)}));return v.fetchAll(),d.fetchAll(),l.fetchAll(),(x,e)=>{const f=z("outside");return r(),p("main",null,[w(X,{to:{name:"monitoring-view"}},{default:M(()=>e[7]||(e[7]=[W("Просмотр камер")])),_:1}),w(Z,null,{default:M(()=>{var o;return[e[8]||(e[8]=u("h1",null,"Видеонаблюдение",-1)),e[9]||(e[9]=u("p",null,"В данном разделе при нажатии на правую кнопку мыши на точке с камерой можно подключиться к камере и увидеть изображение с нее.",-1)),w(Y,{label:"План помещения",options:(o=n(l).elements)==null?void 0:o.map(k=>({value:k.id,label:k.name})),modelValue:n(l).element.id,"onUpdate:modelValue":e[0]||(e[0]=k=>n(l).element.id=k)},null,8,["options","modelValue"])]}),_:1}),B((r(),q(N,{ref_key:"contextmenu",ref:t},{default:M(()=>[u("ul",null,[u("li",{onClick:e[1]||(e[1]=o=>(m.value.showModal(),t.value.close()))},"Подключиться")])]),_:1})),[[f,()=>t.value.close()]]),w(N,{ref_key:"video",ref:m},{default:M(()=>[(r(!0),p(P,null,L(I.value,o=>B((r(),q(O,{key:o.playlist,playlistUrl:`${n(s)}/live/${o.playlist}/index.m3u8`},null,8,["playlistUrl"])),[[f,()=>m.value.close()]])),128))]),_:1},512),u("section",null,[(r(),p("svg",{ref:"svg",xmlns:"http://www.w3.org/2000/svg",viewBox:"0 0 720 720",width:"920",style:R({transform:b.value}),onContextmenu:e[2]||(e[2]=V(o=>t.value.show(o),["prevent"])),onMousedown:e[3]||(e[3]=V((...o)=>n(g)&&n(g)(...o),["prevent"])),onMousemove:e[4]||(e[4]=(...o)=>n(a)&&n(a)(...o)),onMouseup:e[5]||(e[5]=(...o)=>n(c)&&n(c)(...o)),onWheel:e[6]||(e[6]=V((...o)=>n(i)&&n(i)(...o),["prevent"]))},[n(l).element.id?(r(),p("image",{key:0,href:h.value},null,8,ae)):A("",!0),w(re)],36))])])}}}),ge=U(ue,[["__scopeId","data-v-6f5c8a67"]]);export{ge as default};
