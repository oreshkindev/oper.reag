import{C as p}from"./ComponentButton-Cvko8na4.js";import{C as f}from"./ComponentCard-ww-yomY1.js";import{C as _}from"./ComponentHeading-Bd-f_Iyu.js";import{u as h}from"./index-CumWWEpN.js";import{d as C,g as c,c as o,a as r,w as a,h as k,o as u,f as d,b as t,u as i,F as g,i as x,t as e}from"./index-BXV8zl86.js";import"./index-DRseKvvp.js";const y={key:0},S={key:1},q=C({__name:"indexView",setup(w){const s=h();return c(()=>s.fetchAll()),(B,l)=>{const m=k("router-link");return u(),o("main",null,[r(p,{to:{name:"equipment-create"}},{default:a(()=>l[0]||(l[0]=[d("Новая запись")])),_:1}),r(_,null,{default:a(()=>l[1]||(l[1]=[t("h1",null,"Список устройств",-1),t("p",null," При добавлении нового устройства убедитесь что все поля заполнены, после чего данное оборудование появится в выпадающем списке при составлении плана и нанесении точек. ",-1),t("p",null,"Перед добавлением нового оборудования убедитесь, что у вас есть необходимая категория, к которой принадлежит оборудование.",-1)])),_:1}),r(f,{tag:"section"},{default:a(()=>[i(s).elements?(u(),o("table",y,[l[2]||(l[2]=t("thead",null,[t("tr",null,[t("th",null,"Наименование"),t("th",null,"Модель"),t("th",null,"IP"),t("th",null,"HTTP"),t("th",null,"SSH"),t("th",null,"Шкаф"),t("th",null,"Гарантия"),t("th",null,"RTSP")])],-1)),t("tbody",null,[(u(!0),o(g,null,x(i(s).elements,n=>(u(),o("tr",{key:n.id},[t("td",null,[r(m,{to:{name:"equipment-update",params:{id:n.id}}},{default:a(()=>[d(e(n.name),1)]),_:2},1032,["to"])]),t("td",null,e(n.model),1),t("td",null,e(n.ip?"да":"нет"),1),t("td",null,e(n.http?"да":"нет"),1),t("td",null,e(n.ssh?"да":"нет"),1),t("td",null,e(n.racks_id?"да":"нет"),1),t("td",null,e(n.warranties_id?"да":"нет"),1),t("td",null,e(n.rtsp?"да":"нет"),1)]))),128))])])):(u(),o("p",S,"Список пуст"))]),_:1})])}}});export{q as default};