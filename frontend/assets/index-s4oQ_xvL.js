import{i as a}from"./index-DRseKvvp.js";import{l as i,m as u,e as n}from"./index-BXV8zl86.js";const s="/v1/schemes",E=i("scheme",()=>{const c=u(),o=n({description:"",file:"",name:""}),t=n([]);return{dialog:n(!1),elements:t,element:o,save:async()=>{try{const e=await a.post(s,o.value);t.value===null&&(t.value=[]),t.value.push(e.data),c.push({name:"scheme"})}catch(e){console.error("Error saving scheme:",e)}},update:async()=>{try{await a.put([s,o.value.id].join("/"),o.value),c.push({name:"scheme"})}catch(e){console.error("Error updating scheme:",e)}},remove:async()=>{try{await a.delete([s,o.value.id].join("/")),c.push({name:"scheme"})}catch(e){console.error("Error deleting scheme:",e)}},upload:async e=>{try{const r=new FormData;r.append("file",e);const l=await a.post("/docs",r,{headers:{"Content-Type":"multipart/form-data"}});o.value.file=l.data.file}catch(r){console.error("Error uploading scheme:",r)}},fetchAll:async()=>{try{const e=await a.get(s);t.value=e.data}catch(e){console.error("Error fetching schemes:",e)}},fetchOne:async e=>{try{const r=await a.get([s,e].join("/"));o.value=r.data}catch(r){console.error("Error fetching scheme:",r)}}}});export{E as u};