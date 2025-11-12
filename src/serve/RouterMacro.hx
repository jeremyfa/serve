package serve;

#if macro

import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;

using StringTools;

class RouterMacro {

    macro static public function build():Array<Field> {

        var numRoutes:Int = 0;
        var routing = new StringBuf();

        var fields = Context.getBuildFields();

        for (field in fields) {
            if (field.meta != null) {
                for (meta in field.meta) {
                    switch meta.name {
                        case 'get' | 'post' | 'put' | 'delete':
                            if (meta.params == null || meta.params.length == 0) {
                                throw new Error('Missing route param in ${meta.name}() meta', field.pos);
                            }
                            switch field.kind {
                                case FFun(f):
                                    if (numRoutes == 0) {
                                        routing.add('var matched_:Null<Dynamic<String>> = null;\n');
                                    }
                                    else {
                                        routing.add('else ');
                                    }
                                    var method:String = switch meta.name {
                                        case 'get': 'GET';
                                        case 'post': 'POST';
                                        case 'put': 'PUT';
                                        case 'delete': 'DELETE';
                                        case _: null;
                                    }
                                    routing.add('if (req_.method == ');
                                    routing.add(method);
                                    routing.add(' && ((matched_ = matchRoute(');
                                    routing.add(new Printer().printExpr(meta.params[0]).replace("$", ":"));
                                    routing.add(', req_.uri)) != null)) {\n');
                                    routing.add('@:privateAccess req_.routeResolved = true;\n');
                                    routing.add('@:privateAccess req_.params = matched_;\n');
                                    routing.add(field.name);
                                    routing.add('(req_, res_);\n');
                                    routing.add('}\n');
                                    numRoutes++;

                                case _:
                                    throw new Error('Using ${meta.name}() meta is not allowed on this field', field.pos);
                            }

                        case _:
                    }
                }
            }
        }

        if (numRoutes > 0) {

            fields.push({
                name: '_handleRequestRoutes',
                pos: Context.currentPos(),
                kind: FFun({
                    args: [
                        {
                            name: 'req_',
                            type: macro :serve.Request
                        },
                        {
                            name: 'res_',
                            type: macro :serve.Response
                        }
                    ],
                    ret: macro :Void,
                    expr: Context.parse(
                        '{\n' + routing.toString() + '\nelse {\nsuper._handleRequestRoutes(req_, res_);\n}\n}',
                        Context.currentPos()
                    )
                }),
                access: [AOverride]
            });

        }

        return fields;

    }

}

#end
