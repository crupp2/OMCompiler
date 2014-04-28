package TaskSystemDump

import interface SimCodeTV;
import CodegenUtil.*;
import DAEDumpTpl.*;
import SCodeDumpTpl.*;

template dumpTaskSystem(SimCode code, Boolean withOperations)
::=
  match code
  case sc as SIMCODE(modelInfo=mi as MODELINFO(vars=vars as SIMVARS(__))) then
  let res = tasksystemdump_dispatch(code,withOperations)
  let() = textFile(res,'<%fileNamePrefix%>_tasks.xml')
  '<%fileNamePrefix%>_info'
end dumpTaskSystem;

template tasksystemdump_dispatch(SimCode code, Boolean withOperations)
::=
  match code
  case sc as SIMCODE(modelInfo=mi as MODELINFO(vars=vars as SIMVARS(__))) then
  let name = Util.escapeModelicaStringToXmlString(dotPath(mi.name))
  <<
  <?xml version="1.0" encoding="UTF-8"?>
  <?xml-stylesheet type="application/xml" href="tasksystemdump.xsl"?>
  <tasksystemdump model="<%name%>">
  <initial-equations size="<%listLength(initialEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(initialEquations),withOperations)%>
  </initial-equations>
  <dae-equations size="<%listLength(allEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(allEquations),withOperations)%>
  </dae-equations>
  <ode-equations size="<%listLength(listGet(odeEquations,1))%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(listGet(odeEquations,1)),withOperations)%>
  </ode-equations>  
  <alg-equations size="<%listLength(listGet(algebraicEquations,1))%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(listGet(algebraicEquations,1)),withOperations)%>
  </alg-equations>
  <residual-equations size="<%listLength(residualEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(residualEquations),withOperations)%>
  </residual-equations>
  <start-equations size="<%listLength(startValueEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(startValueEquations),withOperations)%>
  </start-equations>
  <nominal-equations size="<%listLength(nominalValueEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(nominalValueEquations),withOperations)%>
  </nominal-equations>
  <min-equations size="<%listLength(minValueEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(minValueEquations),withOperations)%>
  </min-equations>
  <max-equations size="<%listLength(maxValueEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(maxValueEquations),withOperations)%>
  </max-equations>
  <parameter-equations size="<%listLength(parameterEquations)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(parameterEquations),withOperations)%>
  </parameter-equations>
  <assertions size="<%listLength(algorithmAndEquationAsserts)%>">
    <%dumpEqs(SimCodeUtil.sortEqSystems(algorithmAndEquationAsserts),withOperations)%>
  </assertions>
  <jacobian-equations>
    <%dumpEqs(SimCodeUtil.sortEqSystems(jacobianEquations),withOperations)%>
  </jacobian-equations>
  <literals size="<%listLength(literals)%>">
    <% literals |> exp => '<exp><%printExpStrEscaped(exp)%></exp>' ; separator="\n" %>
  </literals>
  <functions size="<%listLength(mi.functions)%>">
    <% mi.functions |> func => match func
      case FUNCTION(__)
      case EXTERNAL_FUNCTION(__)
      case KERNEL_FUNCTION(__)
      case PARALLEL_FUNCTION(__)
      case RECORD_CONSTRUCTOR(__) then
      '<function name="<%Util.escapeModelicaStringToXmlString(dotPath(name))%>"><%dumpInfo(info)%></function>' ; separator="\n"
    %>
  </functions>
  </tasksystemdump><%\n%>
  >>
end tasksystemdump_dispatch;

template eqIndex(SimEqSystem eq)
::=
match eq
    case SES_RESIDUAL(__)
    case SES_SIMPLE_ASSIGN(__)
    case SES_ARRAY_CALL_ASSIGN(__)
    case SES_ALGORITHM(__)
    case SES_LINEAR(__)
    case SES_NONLINEAR(__)
    case SES_MIXED(__)
    case SES_WHEN(__)
    case SES_IFEQUATION(__) then index
    else error(sourceInfo(), "dumpEqs: Unknown equation")
end eqIndex;

template dumpEqs(list<SimEqSystem> eqs, Boolean withOperations)
::= eqs |> eq hasindex i0 =>
  match eq
    case e as SES_RESIDUAL(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
        <residual>
          <% extractUniqueCrefsFromExpDerPreStart(e.exp) |> cr => '<depends name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>
          <rhs><%printExpStrEscaped(e.exp)%></rhs>
        </residual>
      </equation><%\n%>
      >>
    case e as SES_SIMPLE_ASSIGN(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
        <assign>
          <defines name="<%crefStrNoUnderscore(e.cref)%>" />
          <% extractUniqueCrefsFromExpDerPreStart(e.exp) |> cr => '<depends name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>
          <rhs><%printExpStrEscaped(e.exp)%></rhs>
        </assign>
      </equation><%\n%>
      >>
    case e as SES_ARRAY_CALL_ASSIGN(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
        <assign type="array">
          <defines name="<%crefStrNoUnderscore(e.componentRef)%>" />
          <rhs><%printExpStrEscaped(e.exp)%></rhs>
        </assign>
      </equation><%\n%>
      >>
    case e as SES_ALGORITHM(statements={}) then 'empty algorithm<%\n%>'
    case e as SES_ALGORITHM(statements=first::_)
      then
      let uniqcrefs = getdependsices(extractUniqueCrefsFromStatmentS(e.statements))
      <<
      <equation index="<%eqIndex(eq)%>">
        <statement>
          <%uniqcrefs%>
          <stmt>
          <%e.statements |> stmt => escapeModelicaStringToXmlString(ppStmtStr(stmt,2)) %>
          </stmt>
        </statement>
        <%dumpElementSource(getStatementSource(first),withOperations)%>
      </equation><%\n%>
      >>
    case e as SES_LINEAR(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
        <linear size="<%listLength(e.vars)%>" nnz="<%listLength(simJac)%>">
          <%e.vars |> SIMVAR(name=cr) => '<defines name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>
          <%beqs |> exp => '<%extractUniqueCrefsFromExpDerPreStart(exp) |> cr => '<depends name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>' ; separator = "\n" %><%\n%>
          <row>
            <%beqs |> exp => '<cell><%printExpStrEscaped(exp)%></cell>' ; separator = "\n" %><%\n%>
          </row>
          <matrix>
            <%simJac |> (i1,i2,eq) =>
            <<
            <cell row="<%i1%>" col="<%i2%>">
              <%match eq case e as SES_RESIDUAL(__) then
                <<
                <residual><%printExpStrEscaped(e.exp)%></residual>
                >>
               %>
            </cell><%\n%>
            >>
            %>
          </matrix>
        </linear>
      </equation><%\n%>
      >>
    case e as SES_NONLINEAR(__) then
      <<
      <%match e.jacobianMatrix case SOME(({(eqns,_,_)},_,_,_,_,_)) then dumpEqs(SimCodeUtil.sortEqSystems(eqns),withOperations) else ''%>
      <equation index="<%eqIndex(eq)%>">
        <nonlinear indexNonlinear="<%indexNonLinearSystem%>">
          <%e.crefs |> cr => '<defines name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>
          <%e.eqs |> eq => '<eq index="<%eqIndex(eq)%>"/>' ; separator = "\n" %>
        </nonlinear>
      </equation><%\n%>
      <%dumpEqs(SimCodeUtil.sortEqSystems(e.eqs),withOperations)%>
      >>
    case e as SES_MIXED(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
        <mixed size="<%intAdd(listLength(e.discEqs),1)%>">
          <%e.discVars |> SIMVAR(name=cr) => '<defines name="<%crefStrNoUnderscore(cr)%>" />' ; separator = ","%>
          <%e.discEqs |> eq => '<discrete index="<%eqIndex(eq)%>" />'%>
          <continuous index="<%eqIndex(e.cont)%>" />
        </mixed>
      </equation><%\n%>
      <%dumpEqs(fill(e.cont,1),withOperations)%>
      <%dumpEqs(e.discEqs,withOperations)%>
      >>
    case e as SES_WHEN(__) then
      <<
      <equation index="<%eqIndex(eq)%>">
      <when>
        <%conditions |> cond => '<cond><%crefStrNoUnderscore(cond)%></cond>' ; separator="\n" %>
        <defines name="<%crefStrNoUnderscore(e.left)%>" />
        <% extractUniqueCrefsFromExpDerPreStart(e.right) |> cr => '<depends name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n" %>
        <rhs><%printExpStrEscaped(e.right)%></rhs>
      </when>
      </equation><%\n%>
      >>
    case e as SES_IFEQUATION(__) then
      let branches = ifbranches |> (_,eqs) => dumpEqs(eqs,withOperations)
      let elsebr = dumpEqs(elsebranch,withOperations)
      <<
      <%branches%>
      <%elsebr%>
      <equation index="<%eqIndex(eq)%>">
      <ifequation /> <!-- TODO: Fix me -->
      </equation><%\n%>
      >>
    else error(sourceInfo(),"dumpEqs: Unknown equation")
end dumpEqs;

template getdependsices(tuple<list<DAE.ComponentRef>, list<DAE.ComponentRef>> ocrefs)
::=
  match ocrefs
  case (olhscrefs,orhscrefs) then 
  <<
  <%olhscrefs |> cr => '<defines name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n"%>
  <%orhscrefs |> cr => '<depends name="<%crefStrNoUnderscore(cr)%>" />' ; separator = "\n"%>
  >>
  else "Error Printing dependenices"
end getdependsices;

template dumpWithin(Within w)
::=
  match w
    case TOP(__) then "within ;"
    case WITHIN(__) then 'within <%dotPath(path)%>;'
end dumpWithin;

template dumpElementSource(ElementSource source, Boolean withOperations)
::=
  match source
    case s as SOURCE(info=info as INFO(__)) then
      <<
      <source>
        <%dumpInfo(info)%>
        <%s.partOfLst |> w => '<part-of><%dumpWithin(w)%></part-of>' %>
        <%match s.instanceOpt case SOME(cr) then '<instance><%crefStrNoUnderscore(cr)%></instance>' %>
        <%s.connectEquationOptLst |> p => "<connect-equation />"%>
        <%s.typeLst |> p => '<type><%escapeModelicaStringToXmlString(dotPath(p))%></type>' ; separator = "\n" %>
      </source>
      <% if withOperations then <<
      <operations>
        <%s.operations |> op => dumpOperation(op,s.info) ; separator="\n" %>
      </operations>
      >> %>
      >>
end dumpElementSource;

template dumpOperation(SymbolicOperation op, Info info)
::=
  match op
    case FLATTEN(__) then
      <<
      <flattening>
        <original><% Util.escapeModelicaStringToXmlString(dumpEEquation(scode,SCodeDump.defaultOptions)) %></original>
        <% match dae case SOME(dae) then '<flattened><% Util.escapeModelicaStringToXmlString(dumpEquation(dae)) %></flattened>' %>
      </flattening>
      >>
    case SIMPLIFY(__) then
      <<
      <simplify>
        <before><%printEquationExpStrEscaped(before)%></before>
        <after><%printEquationExpStrEscaped(after)%></after>
      </simplify>
      >>
    case SUBSTITUTION(__) then
      <<
      <substitution>
        <before><%printExpStrEscaped(source)%></before>
        <%listReverse(substitutions) |> target => '<exp><%printExpStrEscaped(target)%></exp>' ; separator="\n" %>
      </substitution>
      >>
    case op as OP_INLINE(__) then
      <<
      <inline>
        <before><%printEquationExpStrEscaped(op.before)%></before>
        <after><%printEquationExpStrEscaped(op.after)%></after>
      </inline>
      >>
    case op as OP_SCALARIZE(__) then
      <<
      <scalarize index="<%op.index%>">
        <before><%printEquationExpStrEscaped(op.before)%></before>
        <after><%printEquationExpStrEscaped(op.after)%></after>
      </scalarize>
      >>
    case op as SOLVED(__) then
      <<
      <solved>
        <lhs><%crefStrNoUnderscore(op.cr)%></lhs>
        <rhs><%printExpStrEscaped(op.exp)%></rhs>
      </solved>
      >>
    case op as LINEAR_SOLVED(__) then
      <<
      <linear-solved>
        simple equation from linear system:
          [<%vars |> v => crefStrNoUnderscore(v) ; separator = " ; "%>] = [<%result |> r => r ; separator = " ; "%>]
          [
            <% jac |> row => (row |> r => r ; separator = " "); separator = "\n"%>
          ]
        *
          X
        =
          [<%rhs |> r => r ; separator = " ; "%>]
      </linear-solved>
      >>
    case op as SOLVE(__) then
      <<
      <solve>
        <old>
          <lhs><%printExpStrEscaped(op.exp1)%></lhs>
          <rhs><%printExpStrEscaped(op.exp2)%></rhs>
        </old>
        <new>
          <lhs><%crefStrNoUnderscore(op.cr)%></lhs>
          <rhs><%printExpStrEscaped(op.res)%></rhs>
        </new>
        <assertions>
          <%op.assertConds |> cond => '<assertion><%printExpStrEscaped(cond)%></assertion>'; separator="\n"%>
        </assertions>
      </solve>
      >>
    case op as OP_DIFFERENTIATE(__) then
      <<
      <derivative>
        <exp><%printExpStrEscaped(op.before)%></exp>
        <with-respect-to><%crefStrNoUnderscore(op.cr)%></with-respect-to>
        <result><%printExpStrEscaped(op.after)%></result>
      </derivative>
      >>
    case OP_RESIDUAL(__) then
      <<
      <op-residual>
        <lhs><%printExpStrEscaped(e1)%></lhs>
        <rhs><%printExpStrEscaped(e2)%></rhs>
        <result><%printExpStrEscaped(e)%></result>
      </op-residual>
      >>
    case op as NEW_DUMMY_DER(__) then
      <<
      <dummyderivative>
        <chosen><%crefStrNoUnderscore(op.chosen)%></chosen>
        <%op.candidates |> cr => '<candidate><%crefStrNoUnderscore(cr)%></candidate>' ; separator = "\n"%>
      </dummyderivative>
      >>
    else Tpl.addSourceTemplateError("Unknown operation",info)
end dumpOperation;

template dumpInfo(Info info)
::=
  match info
  case info as INFO(__) then
  '<info file="<%escapeModelicaStringToXmlString(info.fileName)%>" lineStart="<%info.lineNumberStart%>" lineEnd="<%info.lineNumberEnd%>" colStart="<%info.columnNumberStart%>" colEnd="<%info.columnNumberEnd%>"/>'
end dumpInfo;

template printExpStrEscaped(Exp exp)
::=
  escapeModelicaStringToXmlString(printExpStr(exp))
end printExpStrEscaped;

template printEquationExpStrEscaped(EquationExp eq)
::=
  match eq
  case PARTIAL_EQUATION(__)
  case RESIDUAL_EXP(__) then
    printExpStrEscaped(exp)
  case EQUALITY_EXPS(__) then
    '<%printExpStrEscaped(lhs)%> = <%printExpStrEscaped(rhs)%>'
end printEquationExpStrEscaped;

end TaskSystemDump;

// vim: filetype=susan sw=2 sts=2