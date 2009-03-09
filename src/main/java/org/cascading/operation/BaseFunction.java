package org.cascading.operation;

import cascading.flow.FlowProcess;
import cascading.operation.Function;
import cascading.operation.FunctionCall;
import cascading.operation.OperationCall;
import cascading.tuple.Fields;

import java.io.Serializable;

/**
 * @author <a href="mailto:gmarabout@gmail.com">Grégoire Marabout</a>
 */
public class BaseFunction implements Function, Serializable {
    private Fields fieldDeclaration;

    public BaseFunction(Fields fieldDeclaration){
        this.fieldDeclaration = fieldDeclaration;
    }

    public void operate(FlowProcess flowProcess, FunctionCall functionCall){
      
    }

    public void prepare(FlowProcess flowProcess, OperationCall operationCall){
    }

    public void cleanup(FlowProcess flowProcess, OperationCall operationCall){
    }

    public Fields getFieldDeclaration(){
        return this.fieldDeclaration;
    }

    public int getNumArgs(){
        return 0;
    }

}
