import{d as p,c as d,b as a,a as o,w as l,u as n,k as f,o as C,f as m,t as V,j as k,_ as v}from"./index-C-5Ijqs0.js";import{C as r}from"./ComponentButton-DtgHXXqF.js";import{C as x}from"./ComponentCard-KN3mc77x.js";import{C as g}from"./ComponentHeading-DHb8KjUM.js";import{_ as u}from"./ComponentInput.vue_vue_type_script_setup_true_lang-BO31PmJS.js";import{C as w}from"./ComponentFile-D1UDE6jH.js";import{u as _}from"./index-BZJ1ESDE.js";import"./index-CdHm6dqN.js";import"./index-_N8SQgRr.js";const b=p({__name:"updateView",setup(c){const t=_(),i=f();return t.fetchOne(+i.params.id),(q,e)=>(C(),d("main",null,[a("nav",null,[o(r,{to:{name:"scheme"}},{default:l(()=>e[3]||(e[3]=[m("Назад")])),_:1}),o(r,{onClick:n(t).remove},{default:l(()=>e[4]||(e[4]=[m("Удалить")])),_:1},8,["onClick"])]),o(g,null,{default:l(()=>[a("h1",null,[e[5]||(e[5]=m(" Редактирование ")),a("span",null,V(n(t).element.name),1)]),e[6]||(e[6]=a("p",null," Lorem ipsum dolor sit amet consectetur, adipisicing elit. Quae aperiam facere consequuntur reiciendis dolorem unde eos porro cumque in assumenda voluptatum veniam nulla, ipsam magnam quaerat consequatur voluptas, eum perspiciatis? ",-1))]),_:1}),o(x,{tag:"section"},{default:l(()=>[a("form",{onSubmit:e[2]||(e[2]=k(()=>{},["prevent"]))},[o(u,{type:"text",label:"Наименование",modelValue:n(t).element.name,"onUpdate:modelValue":e[0]||(e[0]=s=>n(t).element.name=s)},null,8,["modelValue"]),o(u,{type:"text",label:"Описание",modelValue:n(t).element.description,"onUpdate:modelValue":e[1]||(e[1]=s=>n(t).element.description=s)},null,8,["modelValue"]),o(w),o(r,{onClick:n(t).update},{default:l(()=>e[7]||(e[7]=[m("Сохранить")])),_:1},8,["onClick"])],32)]),_:1})]))}}),H=v(b,[["__scopeId","data-v-3743999f"]]);export{H as default};