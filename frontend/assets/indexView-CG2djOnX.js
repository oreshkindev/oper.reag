import{C as p}from"./ComponentButton-C3DWQZP6.js";import{C as f}from"./ComponentCard-B5uTf3KQ.js";import{C as _}from"./ComponentHeading-DLXMcofr.js";import{u as c}from"./index-BoaXHYdk.js";import{d as C,g as k,c as n,a,w as s,h as g,o,f as u,b as t,u as m,F as x,i as y,t as i}from"./index-C5oIhCp2.js";import"./index-DSbkomb1.js";const h={key:0},B={key:1},D=C({__name:"indexView",setup(V){const l=c();return k(()=>l.fetchAll()),(b,e)=>{const d=g("router-link");return o(),n("main",null,[a(p,{to:{name:"rack-create"}},{default:s(()=>e[0]||(e[0]=[u("Новая запись")])),_:1}),a(_,null,{default:s(()=>e[1]||(e[1]=[t("h1",null,"Телекоммуникационные шкафы",-1),t("p",null," Добавляйте телекоммуникационные шкафы объекта. А при создании карточки оборудования вы сможете указать место размещения данного оборудования, в определенном шкафу. ",-1)])),_:1}),a(f,{tag:"section"},{default:s(()=>[m(l).elements?(o(),n("table",h,[e[2]||(e[2]=t("thead",null,[t("tr",null,[t("th",null,"Наименование"),t("th",null,"Описание")])],-1)),t("tbody",null,[(o(!0),n(x,null,y(m(l).elements,r=>(o(),n("tr",{key:r.id},[t("td",null,[a(d,{to:{name:"rack-update",params:{id:r.id}}},{default:s(()=>[u(i(r.name),1)]),_:2},1032,["to"])]),t("td",null,i(r.description),1)]))),128))])])):(o(),n("p",B,"Список пуст"))]),_:1})])}}});export{D as default};
