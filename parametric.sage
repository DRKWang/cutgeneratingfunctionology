# Make sure current directory is in path.  
# That's not true while doctesting (sage -t).
if '' not in sys.path:
    sys.path = [''] + sys.path

from igp import *

import sage.structure.element
from sage.structure.element import FieldElement

from sage.libs.ppl import Variable, Constraint, Linear_Expression, Constraint_System, NNC_Polyhedron, Poly_Con_Relation, Poly_Gen_Relation, Generator, MIP_Problem
poly_is_included = Poly_Con_Relation.is_included()
#strictly_intersects = Poly_Con_Relation.strictly_intersects()
point_is_included = Poly_Gen_Relation.subsumes()
#con_saturates = Poly_Con_Relation.saturates()

from sage.structure.sage_object import SageObject

###############################
# Symbolic Real Number Field
###############################

default_symbolic_field = None

class SymbolicRNFElement(FieldElement):

    def __init__(self, value, symbolic=None, parent=None):
        if parent is None:
            raise ValueError, "SymbolicRNFElement invoked with parent=None. That's asking for trouble"
            parent = default_symbolic_field
        FieldElement.__init__(self, parent) ## this is so that canonical_coercion works.
        ## Test coercing the value to RR, so that we do not try to build a SymbolicRNFElement
        ## from something like a tuple or something else that does not make any sense.
        RR(value)
        self._val = value
        if symbolic is None:
            self._sym = value # changed to not coerce into SR. -mkoeppe
        else:
            self._sym = symbolic
        self._parent = parent ## this is so that .parent() works.

    def sym(self):
        return self._sym

    def val(self):
        return self._val

    def parent(self):
        return self._parent

    def __cmp__(left, right):
        result = cmp(left._val, right._val)
        if result == 0:
            left.parent().record_to_eq_list(left.sym() - right.sym())
        elif result == -1:
            left.parent().record_to_lt_list(left.sym() - right.sym())
        elif result == 1:
            left.parent().record_to_lt_list(right.sym() - left.sym())
        return result

    def __richcmp__(left, right, op):
        result = left._val.__richcmp__(right._val, op)
        return result

    def __abs__(self):
        if self.sign() >= 0:
            return self
        else:
            return -self

    def sign(self):
        parent = self._val.parent()
        return cmp(self._val, parent._zero_element)

    def floor(self):
        result = floor(self._val)
        result <= self < result + 1
        return result

    def ceil(self):
        result = ceil(self._val)
        result - 1 < self <= result
        return result

    def __float__(self):
        return float(self._val)

    def __repr__(self):
        r = repr(self._sym)
        if len(r) > 1:
            return '('+r+')~'
        else:
            return r+'~'

    def _latex_(self):
        return "%s" % (latex(self._sym))

    def __add__(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val + other._val, self._sym + other._sym, parent=self.parent())
    def _add_(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val + other._val, self._sym + other._sym, parent=self.parent())

    def __sub__(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val - other._val, self._sym - other._sym, parent=self.parent())

    def __neg__(self):
        return SymbolicRNFElement(-self._val, -self._sym, parent=self.parent())

    def __mul__(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val * other._val, self._sym * other._sym, parent=self.parent())
    def _mul_(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val * other._val, self._sym * other._sym, parent=self.parent())

    def __div__(self, other):
        if not isinstance(other, SymbolicRNFElement):
            other = SymbolicRNFElement(other, parent=self.parent())
        return SymbolicRNFElement(self._val / other._val, self._sym / other._sym, parent=self.parent())


from sage.rings.ring import Field
import sage.rings.number_field.number_field_base as number_field_base
from sage.structure.coerce_maps import CallableConvertMap
from itertools import izip

class SymbolicRealNumberField(Field):
    """
    Parametric search:
    EXAMPLES::

        sage: logging.disable(logging.INFO)             # Suppress output in automatic tests.
        sage: K.<f> = SymbolicRealNumberField([4/5])
        sage: h = gmic(f, field=K)
        sage: _ = generate_maximal_additive_faces(h);
        sage: list(K.get_eq_list()), list(K.get_lt_list())
        ([], [2*f - 2, f - 2, -f, f - 1, -1/f, -f - 1, -2*f, -2*f + 1, -1/(-f^2 + f)])
        sage: list(K.get_eq_poly()), list(K.get_lt_poly())
        ([], [2*f - 2, f - 2, f^2 - f, -f, f - 1, -f - 1, -2*f, -2*f + 1])
        sage: list(K.get_eq_factor()), list(K.get_lt_factor())
        ([], [-f + 1/2, f - 1, -f])

        sage: K.<f, lam> = SymbolicRealNumberField([4/5, 1/6])
        sage: h = gj_2_slope(f, lam, field=K)
        sage: list(K.get_lt_list())
        [-1/2*f*lam - 1/2*f + 1/2*lam, lam - 1, f - 1, -lam, (-f*lam - f + lam)/(-f + 1), f*lam - lam, (-1/2)/(-1/2*f^2*lam - 1/2*f^2 + f*lam + 1/2*f - 1/2*lam), -f]
        sage: list(K.get_lt_poly())
        [f - 1, -f*lam - f + lam, -1/2*f*lam - 1/2*f + 1/2*lam, 1/2*f^2*lam + 1/2*f^2 - f*lam - 1/2*f + 1/2*lam, -lam, f*lam - lam, -f, lam - 1]
        sage: list(K.get_lt_factor())
        [-lam, f - 1, -f*lam - f + lam, -f, lam - 1]

        sage: K.<f,alpha> = SymbolicRealNumberField([4/5, 3/10])
        sage: h=dg_2_step_mir(f, alpha, field=K, conditioncheck=False)
        sage: extremality_test(h)
        True

        sage: K.<f,a1,a2,a3> = SymbolicRealNumberField([4/5, 1, 3/10, 2/25])
        sage: h = kf_n_step_mir(f, (a1, a2, a3), conditioncheck=False)
        sage: extremality_test(h)
        True

        sage: K.<f> = SymbolicRealNumberField([1/5])
        sage: h = drlm_3_slope_limit(f, conditioncheck=False)
        sage: extremality_test(h)
        True
        sage: list(K.get_lt_factor())
        [f - 1/2, f - 1/3, f - 1, -f]
    """

    def __init__(self, values=[], names=()):
        NumberField.__init__(self)
        self._element_class = SymbolicRNFElement
        self._zero_element = SymbolicRNFElement(0, parent=self)
        self._one_element =  SymbolicRNFElement(1, parent=self)
        self._eq = set([])
        self._lt = set([])
        self._eq_poly = set([])
        self._lt_poly = set([])
        self._eq_factor = set([])
        self._lt_factor = set([])
        vnames = PolynomialRing(QQ, names).fraction_field().gens();
        self._gens = [ SymbolicRNFElement(value, name, parent=self) for (value, name) in izip(values, vnames) ]
        self._names = names
        self._values = values

        # do the computation of the polyhedron incrementally,
        # rather than first building a huge list and then in a second step processing it.
        # the polyhedron defined by all constraints in self._eq/lt_factor
        self.polyhedron = NNC_Polyhedron(0, 'universe')
        # records the monomials that appear in self._eq/lt_factor
        self.monomial_list = []
        # a dictionary that maps each monomial to the index of its corresponding Variable in self.polyhedron
        self.v_dict = {}
        # record QQ_linearly_independent of pairs. needs simplification
        self._independent_pairs = set([])
        self._dependency= []
        self._independency=[]
        self._zero_kernel=set([])

    def __copy__(self):
        logging.warn("copy(%s) is invoked" % self)
        Kcopy = self.__class__(self._values, self._names)
        Kcopy._eq.update(self._eq)
        Kcopy._lt.update(self._lt)
        Kcopy._eq_poly.update(self._eq_poly)
        Kcopy._lt_poly.update(self._lt_poly)
        Kcopy._eq_factor.update(self._eq_factor)
        Kcopy._lt_factor.update(self._lt_factor)
        return Kcopy

    def _first_ngens(self, n):
        for i in range(n):
            yield self._gens[i]
    def ngens(self):
        return len(self._gens)
    def _an_element_impl(self):
        return SymbolicRNFElement(1, parent=self)
    def _coerce_map_from_(self, S):
        return CallableConvertMap(S, self, lambda s: SymbolicRNFElement(s, parent=self), parent_as_first_arg=False)
    def __repr__(self):
        return 'SymbolicRNF%s' %repr(self.gens())
    def __call__(self, elt):
        if parent(elt) == self:
            return elt
        try: 
            QQ_elt = QQ(elt)
            return SymbolicRNFElement(QQ_elt, parent=self)
        except:
            raise ValueError, "SymbolicRealNumberField called with element", elt

    def _coerce_impl(self, x):
        return self(x)
    def get_eq_list(self):
        return self._eq
    def get_lt_list(self):
        return self._lt
    def get_eq_poly(self):
        return self._eq_poly
    def get_lt_poly(self):
        return self._lt_poly
    def get_eq_factor(self):
        return self._eq_factor
    def get_lt_factor(self):
        return self._lt_factor
    def record_to_eq_list(self, comparison):
        if not comparison.is_zero() and not comparison in QQ and not comparison in self._eq:
            logging.debug("New element in %s._eq: %s" % (repr(self), comparison))
            self._eq.add(comparison)
            self.record_poly(comparison.numerator())
            self.record_poly(comparison.denominator())
    def record_to_lt_list(self, comparison):
        if not comparison in QQ and not comparison in self._lt:
            logging.debug("New element in %s._lt: %s" % (repr(self), comparison))
            self._lt.add(comparison)
            self.record_poly(comparison.numerator())
            self.record_poly(comparison.denominator())
    def record_poly(self, poly):
        if not poly in QQ and poly.degree() > 0:
            v = poly(self._values)
            if v == 0:
                self.record_to_eq_poly(poly)
            elif v < 0:
                self.record_to_lt_poly(poly)
            else:
                self.record_to_lt_poly(-poly)
    def record_to_eq_poly(self, poly):
        if not poly in self._eq_poly:
            self._eq_poly.add(poly)
            for (fac, d) in poly.factor():
                # record the factor if it's zero
                if fac(self._values) == 0 and not fac in self._eq_factor:
                    self.record_factor(fac, operator.eq)

    def record_to_lt_poly(self, poly):
        if not poly in self._lt_poly:
            self._lt_poly.add(poly)
            for (fac, d) in poly.factor():
                # record the factor if it's raised to an odd power.
                if d % 2 == 1:
                    if fac(self._values) < 0:
                        new_fac = fac
                    else:
                        new_fac = -fac
                    if not new_fac in self._lt_factor:
                        self.record_factor(new_fac, operator.lt)

    def record_factor(self, fac, op):
        #print "add %s, %s to %s" % (fac, op, self.polyhedron.constraints())
        space_dim_old = len(self.monomial_list)
        linexpr = polynomial_to_linexpr(fac, self.monomial_list, self.v_dict)
        space_dim_to_add = len(self.monomial_list) - space_dim_old
        if op == operator.lt:
            constraint_to_add = (linexpr < 0)
        else:
            constraint_to_add = (linexpr == 0)
        #print "constraint_to_add = %s" % constraint_to_add
        if space_dim_to_add:
            self.polyhedron.add_space_dimensions_and_embed(space_dim_to_add)
            add_new_element = True
        else:
            add_new_element = not self.polyhedron.relation_with(constraint_to_add).implies(poly_is_included)
        if add_new_element:
            self.polyhedron.add_constraint(constraint_to_add)
            #print " add new constraint, %s" %self.polyhedron.constraints()
            if op == operator.lt:
                logging.info("New constraint: %s < 0" % fac)
                self._lt_factor.add(fac)
            else:
                logging.info("New constraint: %s == 0" % fac)
                self._eq_factor.add(fac)

    def record_independence_of_pair(self, numbers, is_independent):
        if len(numbers) != 2:
            raise NotImplementedError, "%s has more than two elements. Not implemented." % numbers
        t1 = affine_linear_form_of_symbolicrnfelement(numbers[0])
        t2 = affine_linear_form_of_symbolicrnfelement(numbers[1])
        vector_space = VectorSpace(QQ,len(t1))
        t1 = vector_space(t1)
        t2 = vector_space(t2)
        pair_space = vector_space.subspace([t1, t2])
        if pair_space.dimension() <= 1:
            if is_independent:
                raise ValueError, "Contradiction: (%s, %s) are not linearly independent in Q." % (t1, t2)
        else:
            if is_independent:
                self._independent_pairs.add(pair_space)
                self._zero_kernel.add(vector_space.subspace([t1]).gen(0))
                self._zero_kernel.add(vector_space.subspace([t2]).gen(0))
            else:
                self._dependency = update_dependency(self._dependency, pair_space)

    def construct_independency(self):
        self._independency, self._zero_kernel = construct_independency(self._independent_pairs, self._dependency, self._zero_kernel)

    def get_reduced_independent_pairs(self):
        if not self._independency:
            self._independency, self._zero_kernel = construct_independency(\
                self._independent_pairs, self._dependency, self._zero_kernel)
        reduced_independent_pairs = get_independent_pairs_from_independency(self._independency)
        return reduced_independent_pairs

default_symbolic_field = SymbolicRealNumberField()


###############################
# Simplify polynomials
###############################

def polynomial_to_linexpr(t, monomial_list, v_dict):
    """
    sage: P.<x,y,z> = QQ[]
    sage: monomial_list = []; v_dict = {};
    sage: t = 27/113 * x^2 + y*z + 1/2
    sage: polynomial_to_linexpr(t, monomial_list, v_dict)
    54*x0+226*x1+113
    sage: monomial_list
    [x^2, y*z]
    sage: v_dict
    {y*z: 1, x^2: 0}

    sage: tt = x + 1/3 * y*z
    sage: polynomial_to_linexpr(tt, monomial_list, v_dict)
    x1+3*x2
    sage: monomial_list
    [x^2, y*z, x]
    sage: v_dict
    {x: 2, y*z: 1, x^2: 0}
    """
    # coefficients in ppl constraint must be integers.
    lcd = lcm([x.denominator() for x in t.coefficients()])
    linexpr = Linear_Expression(0)
    if len(t.args()) <= 1:
        # sage.rings.polynomial.polynomial_rational_flint object has no attribute 'monomials'
        for (k, c) in t.dict().items():
            m = (t.args()[0])^k
            if m in v_dict.keys():
                v = Variable(v_dict[m])
            elif k == 0:
                # constant term, don't construct a new Variable for it.
                v = 1
            else:
                nv = len(monomial_list)
                v = Variable(nv)
                v_dict[m] = nv
                monomial_list.append(m)
            linexpr += (lcd * c) * v
    else:
        for m in t.monomials():
            if m in v_dict.keys():
                v = Variable(v_dict[m])
            elif m == 1:
                v = 1
            else:
                nv = len(monomial_list)
                v = Variable(nv)
                v_dict[m] = nv
                monomial_list.append(m)
            coeffv = t.monomial_coefficient(m)
            linexpr += (lcd * coeffv) * v
    return linexpr

def cs_of_eq_lt_poly(eq_poly, lt_poly):
    """
    sage: P.<f>=QQ[]
    sage: eq_poly =[]; lt_poly = [2*f - 2, f - 2, f^2 - f, -2*f, f - 1, -f - 1, -f, -2*f + 1]
    sage: cs, monomial_list, v_dict = cs_of_eq_lt_poly(eq_poly, lt_poly)
    sage: cs
    Constraint_System {-x0+1>0, -x0+2>0, x0-x1>0, x0>0, -x0+1>0, x0+1>0, x0>0, 2*x0-1>0}
    sage: monomial_list
    [f, f^2]
    sage: v_dict
    {f: 0, f^2: 1}
    """
    monomial_list = []
    v_dict ={}
    cs = Constraint_System()
    for t in eq_poly:
        linexpr = polynomial_to_linexpr(t, monomial_list, v_dict)
        cs.insert( linexpr == 0 )
    for t in lt_poly:
        linexpr = polynomial_to_linexpr(t, monomial_list, v_dict)
        cs.insert( linexpr < 0 )
    return cs, monomial_list, v_dict

def simplify_eq_lt_poly_via_ppl(eq_poly, lt_poly):
    """
    Given polymonial equality and inequality lists.
    Treat each monomial as a new variable.
    This gives a linear inequality system.
    Remove redundant inequalities using PPL.

    EXAMPLES::

        sage: logging.disable(logging.INFO)             # Suppress output in automatic tests.
        sage: K.<f> = SymbolicRealNumberField([4/5])
        sage: h = gmic(f, field=K)
        sage: _ = extremality_test(h)
        sage: eq_poly =list(K.get_eq_poly())
        sage: lt_poly =list(K.get_lt_poly())
        sage: (eq_poly, lt_poly)
        ([], [2*f - 2, f - 2, f^2 - f, -2*f, f - 1, -f - 1, -f, -2*f + 1])
        sage: simplify_eq_lt_poly_via_ppl(eq_poly, lt_poly)
        ([], [f - 1, -2*f + 1, f^2 - f])

        sage: eq_factor =list(K.get_eq_factor())
        sage: lt_factor =list(K.get_lt_factor())
        sage: (eq_factor, lt_factor)
        ([], [-f + 1/2, f - 1, -f])
        sage: simplify_eq_lt_poly_via_ppl(eq_factor, lt_factor)
        ([], [f - 1, -2*f + 1])

        sage: K.<f, lam> = SymbolicRealNumberField([4/5, 1/6])
        sage: h = gj_2_slope(f, lam, field=K, conditioncheck=False)
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_poly()), list(K.get_lt_poly()))
        ([],
         [f*lam - lam,
          f - 1,
          f^2*lam + f^2 - 2*f*lam - f + lam,
          -f*lam - f + lam,
          -lam])
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_factor()), list(K.get_lt_factor()))
        ([], [-f*lam - f + lam, f - 1, -lam, -f])

        sage: _ = extremality_test(h)
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_poly()), list(K.get_lt_poly()))
        ([], [f^2*lam + f^2 - 2*f*lam - f + lam, -2*f*lam + f + 2*lam - 1, -f*lam - 3*f + lam + 2, -lam, lam - 1, f*lam - lam])
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_factor()), list(K.get_lt_factor()))
        ([],
         [-3*f*lam - f + 3*lam,
          3*f*lam - f - 3*lam,
          -f*lam - 3*f + lam + 2,
          f*lam - 3*f - lam + 2,
          f - 1,
          2*lam - 1,
          -lam])

        sage: K.<f,alpha> = SymbolicRealNumberField([4/5, 3/10])             # Bad example! parameter region = {given point}.
        sage: h=dg_2_step_mir(f, alpha, field=K, conditioncheck=False)
        sage: _ = extremality_test(h)
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_poly()), list(K.get_lt_poly()))
        ([-10*alpha + 3, -5*f + 4], [5*f^2 - 10*f*alpha - 1])
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_factor()), list(K.get_lt_factor()))
        ([-10*alpha + 3, -5*f + 4], [])

        sage: K.<f> = SymbolicRealNumberField([1/5])
        sage: h = drlm_3_slope_limit(f, conditioncheck=False)
        sage: _ = extremality_test(h)
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_poly()), list(K.get_lt_poly()))
        ([], [3*f - 1, -f^2 - f, -f])
        sage: simplify_eq_lt_poly_via_ppl(list(K.get_eq_factor()), list(K.get_lt_factor()))
        ([], [3*f - 1, -f])

    """
    cs, monomial_list, v_dict = cs_of_eq_lt_poly(eq_poly, lt_poly)
    p = NNC_Polyhedron(cs)
    return read_leq_lin_from_polyhedron(p, monomial_list, v_dict)


def read_leq_lin_from_polyhedron(p, monomial_list, v_dict, tightened_mip=None): #, check_variable_elimination=False):
    """
    sage: P.<f>=QQ[]
    sage: eq_poly =[]; lt_poly = [2*f - 2, f - 2, f^2 - f, -2*f, f - 1, -f - 1, -f, -2*f + 1]
    sage: cs, monomial_list, v_dict = cs_of_eq_lt_poly(eq_poly, lt_poly)
    sage: p = NNC_Polyhedron(cs)
    sage: read_leq_lin_from_polyhedron(p, monomial_list, v_dict)
    ([], [f - 1, -2*f + 1, f^2 - f])
    """
    mineq = []
    minlt = []
    mincs = p.minimized_constraints()
    for c in mincs:
        if tightened_mip is not None and is_not_a_downstairs_wall(c, tightened_mip):
            # McCormick trash, don't put in minlt.
            continue
        coeff = c.coefficients()
        # observe: coeffients in a constraint of NNC_Polyhedron could have gcd != 1.
        # take care of this.
        gcd_c = gcd(gcd(coeff), c.inhomogeneous_term())
        # constraint is written with '>', while lt_poly records '<' relation
        t = sum([-(x/gcd_c)*y for x, y in itertools.izip(coeff, monomial_list)]) - c.inhomogeneous_term()/gcd_c
        if c.is_equality():
            mineq.append(t)
            #if check_variable_elimination and (not variable_elimination_is_done_for_mincs(mincs)):
            #    raise NotImplementedError, "Alas, PPL didn't do its job for eliminating variables in the minimized constraint system %s." % self.polyhedron.minimized_constraints()
            #check_variable_elimination = False
        else:
            minlt.append(t)
    # note that polynomials in mineq and minlt can have leading coefficient != 1
    return mineq, minlt

def read_simplified_leq_lin(K, level="factor"):
    """
    sage: K.<f> = SymbolicRealNumberField([4/5])
    sage: h = gmic(f, field=K)
    sage: _ = extremality_test(h)
    sage: read_simplified_leq_lin(K)
    ([], [f - 1, -2*f + 1])

    sage: K.<f> = SymbolicRealNumberField([1/5])
    sage: h = drlm_3_slope_limit(f, conditioncheck=False)
    sage: _ = extremality_test(h)
    sage: read_simplified_leq_lin(K)
    ([], [3*f - 1, -f])
    """
    if level == "factor":
        #leq, lin = simplify_eq_lt_poly_via_ppl(K.get_eq_factor(), K.get_lt_factor())
        # Since we update K.polyhedron incrementally,
        # just read leq and lin from its minimized constraint system.
        leq, lin = read_leq_lin_from_polyhedron(K.polyhedron, K.monomial_list, K.v_dict)
    elif level == "poly":
        leq, lin = simplify_eq_lt_poly_via_ppl(K.get_eq_poly(), K.get_lt_poly())
    else:
        leq = list(K.get_eq_list())
        lin = list(K.get_lt_list())
    if leq:
        logging.warn("equation list %s is not empty!" % leq)
    return leq, lin

def variable_elimination_is_done_for_mincs(mincs):
    # check the assumption about minimized_constraints:
    # Let c_eq be an equation constraint in mincs.
    # At least one of the variables in c_eq does not appear in any other constraints of mincs.
    # This function is not used, as check_variable_elimination=False in read_leq_lin_from_polyhedron(). But we do the check in find_pivot_variables().
    m = len(mincs)
    n = mincs.space_dimension()
    coef = [c.coefficients() for c in mincs]
    for i in range(m):
        if mincs[i].is_equality():
            has_eliminated_variable = False
            for k in range(n):
                if (coef[i][k] != 0) and all(coef[j][k] == 0 for j in range(m) if j != i):
                    has_eliminated_variable = True
                    break
            if not has_eliminated_variable:
                return False
    return True

def find_pivot_variables(leqs, lins):
    # FIXME: Polynomial_rational_flint doesn't have .monomials() .monomial_coefficient
    # assume equations and inequalites are linear.
    # compute the pivot variable of each leqs.
    variables = lins[0].args()
    pivots = []
    if not leqs:
        return pivots
    monomials_not_in_lins = set(variables)
    for ineq in lins:
        monomials_not_in_lins -= set(ineq.monomials())
    n = len(leqs)
    for i in range(n):
        found_pivot = False
        for v in monomials_not_in_lins:
            if (leqs[i].monomial_coefficient(v) != 0) and \
               all(leqs[j].monomial_coefficient(v) == 0 for j in range(n) if j != i):
                pivots.append(v)
                found_pivot = True
                break
        if not found_pivot:
            raise NotImplementedError, "Alas, PPL didn't do its job for eliminating variables in the system %s == 0, %s < 0." % (leqs, lins)
    return pivots

def solve_for_pivot_variables(pt, leqs, pivot_variables):
    if not leqs:
        return pt #type is vector
    new_pt = list(pt)
    variables = leqs[0].args()
    for (pv, eqn) in izip(pivot_variables, leqs):
        i = variables.index(pv)
        coef = eqn.monomial_coefficient(pv)
        vi = (coef*pv - eqn)(*new_pt) / coef
        new_pt[i] = vi
    return vector(new_pt)

######################################
# Extreme functions with the magic K
######################################

from sage.misc.sageinspect import sage_getargspec, sage_getvariablename

def read_default_args(function, **opt_non_default):
    """
    sage: read_default_args(gmic)
    {'conditioncheck': True, 'f': 4/5, 'field': None}
    sage: read_default_args(drlm_backward_3_slope, **{'bkpt': 1/5})
    {'bkpt': 1/5, 'conditioncheck': True, 'f': 1/12, 'field': None}
    """
    args, varargs, keywords, defaults = sage_getargspec(function)
    default_args = {}
    for i in range(len(defaults)):
        default_args[args[-i-1]]=defaults[-i-1]
    for (opt_name, opt_value) in opt_non_default.items():
        if opt_name in default_args:
            default_args[opt_name] = opt_value
    return default_args

def construct_field_and_test_point(function, var_name, var_value, default_args):
    """
    sage: function=gmic; var_name=['f']; var_value=[1/2];
    sage: default_args = read_default_args(function)
    sage: K, test_point = construct_field_and_test_point(function, var_name, var_value, default_args)
    sage: K
    SymbolicRNF[f~]
    sage: test_point
    {'conditioncheck': False, 'f': f~, 'field': SymbolicRNF[f~]}
    """
    K = SymbolicRealNumberField(var_value, var_name)
    test_point = copy(default_args)
    for i in range(len(var_name)):
        test_point[var_name[i]] = K.gens()[i]
    test_point['field'] = K
    test_point['conditioncheck'] = False
    return K, test_point

def simplified_extremality_test(function):
    """
    function has rational bkpts; function is known to be minimal.
    """
    f = find_f(function, no_error_if_not_minimal_anyway=True)
    covered_intervals = generate_covered_intervals(function)
    uncovered_intervals = generate_uncovered_intervals(function)
    if uncovered_intervals:
        logging.info("Function has uncovered intervals, thus is NOT extreme.")
        return False
    else:
        components = covered_intervals
    field = function(0).parent().fraction_field()
    symbolic = generate_symbolic(function, components, field=field)
    equation_matrix = generate_additivity_equations(function, symbolic, field, f=f)
    slope_jump_vects = equation_matrix.right_kernel_matrix()
    sol_dim = slope_jump_vects.nrows()
    if sol_dim > 0:
        logging.info("Finite dimensional test: Solution space has dimension %s" % sol_dim)
        logging.info("Thus the function is NOT extreme.")
        return False
    else:
        logging.info("The function is extreme.")
        return True

##############################
# Find regions
#############################

def find_region_according_to_literature(function, var_name, var_value, region_level, default_args=None, \
                                        level="factor", non_algrebraic_warn=True, **opt_non_default):
    """
    sage: find_region_according_to_literature(gmic, ['f'], [4/5], 'constructible')
    ([], [f - 1, -f])
    sage: find_region_according_to_literature(drlm_backward_3_slope, ['f','bkpt'], [1/12, 2/12], 'extreme')
    ([], [f - bkpt, -f + 4*bkpt - 1, -f])
    """
    ## Note: region_level = 'constructible' / 'extreme'
    if default_args is None:
        default_args = read_default_args(function, **opt_non_default)
    if not isinstance(function, ExtremeFunctionsFactory):
        K, test_point = construct_field_and_test_point(function, var_name, var_value, default_args)
        if region_level == 'extreme':
            test_point['conditioncheck'] = True
        h = function(**test_point)
        leq, lin =  read_simplified_leq_lin(K, level=level)
        if leq:
            logging.warn("Bad default arguments!")
        return leq, lin
    else:
        if non_algrebraic_warn:
            logging.warn("This function involves non-algebraic operations. Parameter region according to literature was plotted separately.")
        test_point = copy(default_args)
        del test_point['field']
        del test_point['conditioncheck']
        for v in var_name:
            del test_point[v]
        x, y = var('x, y')
        if region_level == 'constructible':
            if len(var_name) == 2:
                return lambda x, y: function.claimed_parameter_attributes(**dict({var_name[0]: x, var_name[1]: y}, **test_point)) != 'not_constructible'
            else:
                return lambda x, y: function.claimed_parameter_attributes(**dict({var_name[0]: x}, **test_point )) != 'not_constructible'
        elif region_level == 'extreme':
            if len(var_name) == 2:
                return lambda x, y: function.claimed_parameter_attributes(**dict({var_name[0]: x, var_name[1]: y}, **test_point)) == 'extreme'
            else:
                return lambda x, y: function.claimed_parameter_attributes(**dict({var_name[0]: x}, **test_point )) == 'extreme'
        else:
            raise ValueError, "Bad argument region_level = %s" % region_level

def find_region_around_given_point(K, h, level="factor", region_level='extreme', is_minimal=None, use_simplified_extremality_test=True):
    ## Note: region_level = 'constructible' / 'minimal'/ 'extreme'. test cases see find_parameter_region()
    region_type = find_region_type_around_given_point(K, h, region_level=region_level, is_minimal=is_minimal, use_simplified_extremality_test=use_simplified_extremality_test)
    leq, lin = read_simplified_leq_lin(K, level=level)
    return region_type, leq, lin

def find_region_type_around_given_point(K, h, region_level='extreme', is_minimal=None, use_simplified_extremality_test=True):
    ## Note: region_level = 'constructible' / 'minimal'/ 'extreme'. test cases see find_parameter_region()
    if h is None:
        return 'not_constructible'
    if region_level == 'constructible':
        return 'is_constructible'
    if is_minimal is None:
        is_minimal = minimality_test(h)
    if is_minimal:
        if region_level == 'minimal':
            return 'is_minimal'
        if use_simplified_extremality_test:
            is_extreme = simplified_extremality_test(h)
        else:
            is_extreme = extremality_test(h)
        if is_extreme:
            return 'is_extreme'
        else:
            return 'not_extreme'
    else:
        return 'not_minimal'

def find_parameter_region(function=drlm_backward_3_slope, var_name=['f'], var_value=None, use_simplified_extremality_test=True,\
                        level="factor", region_level='extreme', **opt_non_default):
    """
    sage: find_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/12+1/30, 2/12], region_level='constructible')
    ('is_constructible', [], [f - bkpt, -f + 2*bkpt - 1, -f])
    sage: find_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/12+1/30, 2/12], region_level='minimal')
    ('is_minimal', [], [f - bkpt, -f + 3*bkpt - 1, -2*f + bkpt])
    sage: find_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/12+1/30, 2/12], region_level='extreme')
    ('is_extreme', [], [f - bkpt, -f + 4*bkpt - 1, -2*f + bkpt, f^2 - f*bkpt - 1])
    """
    # similar to find_region_around_given_point(), but start from constructing K and test point.
    default_args = read_default_args(function, **opt_non_default)
    if not var_value:
        var_value = [default_args[v] for v in var_name]
    K, test_point = construct_field_and_test_point(function, var_name, var_value, default_args)
    try:
        h = function(**test_point)
    except:
        h = None
    region_type, leq, lin = find_region_around_given_point(K, h, level=level, region_level=region_level, \
                        is_minimal=None, use_simplified_extremality_test=use_simplified_extremality_test)
    return region_type, leq, lin

##############################
# Plot regions
#############################
def plot_region_given_dim_and_description(d, region_description, color, alpha=0.5, xmin=-0.1, xmax=1.1, ymin=-0.1, ymax=1.1, plot_points=1000):
    x, y = var('x, y')
    if type(region_description) is tuple:
        leq, lin = region_description
        if d == 2:
            return region_plot([ lhs(x, y) == 0 for lhs in leq ] + [ lhs(x, y) < 0 for lhs in lin ], \
                    (x, xmin, xmax), (y, ymin, ymax), incol=color, alpha=alpha, plot_points=plot_points, bordercol=color)
        else:
            return region_plot([ lhs(x) == 0 for lhs in leq ] + [ lhs(x) < 0 for lhs in lin ] + [y >= -0.01, y <= 0.01], \
                    (x, xmin, xmax), (y, -0.1, 0.3), incol=color, alpha=alpha, plot_points=plot_points, bordercol=color, ticks=[None,[]])
    else:
        # region_description is a lambda function,
        # such as find_region_according_to_literature(function from factory classes)
        if d == 2:
            return region_plot([region_description], (x, xmin, xmax), (y, ymin, ymax), \
                    incol=color, alpha=alpha, plot_points=plot_points, bordercol=color)
        else:
            return region_plot([region_description] + [y >= -0.01, y <= 0.01], (x, xmin, xmax), (y, -0.1, 0.3), \
                    incol=color, alpha=alpha, plot_points=plot_points, bordercol=color, ticks=[None,[]])

def plot_region_according_to_literature(function, var_name, default_args=None, level="factor", \
                                        alpha=0.5, xmin=-0.1, xmax=1.1, ymin=-0.1, ymax=1.1, plot_points=1000, **opt_non_default):
    """
    sage: plot_region_according_to_literature(drlm_backward_3_slope, ['f','bkpt'], plot_points=1000) # not tested
    sage: plot_region_according_to_literature(gj_forward_3_slope, ['lambda_1', 'lambda_2'], f = 2/3, plot_points=500)  # not tested
    sage: plot_region_according_to_literature(dg_2_step_mir, ['f','alpha'], plot_points=500)  # not tested
    """
    if default_args is None:
        default_args = read_default_args(function, **opt_non_default)
    var_value = [default_args[v] for v in var_name]
    g = Graphics()
    d = len(var_name)
    region_constructible = find_region_according_to_literature(function, var_name, var_value, 'constructible', default_args, level=level)
    g += plot_region_given_dim_and_description(d, region_constructible, "orange", \
                    alpha=alpha, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
    g += line([(0,0),(0,0.01)], color = "orange", legend_label="constructible", zorder=-10)
    region_extreme = find_region_according_to_literature(function, var_name, var_value, 'extreme', default_args, level=level, non_algrebraic_warn=False)
    g += plot_region_given_dim_and_description(d, region_extreme, "red", \
                    alpha=alpha, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
    g += line([(0,0),(0,0.01)], color ="red", legend_label="claimed_extreme", zorder=-10)
    return g

def plot_covered_regions(regions, tested_points, d, alpha=0.5, xmin=-0.1, xmax=1.1, ymin=-0.1, ymax=1.1, plot_points=1000, show_points=2):
    covered_type_color = {'not_minimal': 'orange', 'not_extreme': 'green', 'is_extreme': 'blue'}
    g = Graphics()
    for (covered_type, leq, lin) in regions:
        g += plot_region_given_dim_and_description(d, (leq, lin), color=covered_type_color[covered_type], \
                            alpha=alpha, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
    # show_points: 0 -- don't show points, 1 -- show white points; 2 -- show all points
    if show_points:
        for (p_val, p_col) in tested_points:
            if show_points == 1 and p_col == 'black':
                # don't plot black points out of the constructible region.
                continue
            if d == 2:
                g += point([p_val], color = p_col, size = 2, zorder=10)
            else:
                g += point([(p_val[0], 0)], color = p_col, size = 2, zorder=10)
    return g

def plot_parameter_region(function=drlm_backward_3_slope, var_name=['f'], var_value=None, use_simplified_extremality_test=True,\
                        alpha=0.5, xmin=-0.1, xmax=1.1, ymin=-0.1, ymax=1.1, level="factor", plot_points=1000, **opt_non_default):

    """
    sage: logging.disable(logging.INFO) # not tested
    sage: g, fname, fparam = plot_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/12-1/30, 2/12]) # not tested
    sage: g.save(fname+".pdf", title=fname+fparam, legend_loc=7) # not tested

    sage: plot_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/12+1/30, 2/12], plot_points=500) # not tested
    sage: plot_parameter_region(drlm_backward_3_slope, ['f','bkpt'], [1/10-1/100, 3/10], plot_points=500) # not tested

    sage: plot_parameter_region(gj_2_slope, ['f','lambda_1'], plot_points=100) # not tested
    sage: plot_parameter_region(gj_2_slope, ['f','lambda_1'], [4/5, 4/6], plot_points=100) # not tested

    sage: plot_parameter_region(gj_forward_3_slope, ['f','lambda_1'], [9/10, 3/10]) # not tested
    sage: plot_parameter_region(gj_forward_3_slope, ['lambda_1','lambda_2']) # not tested
    sage: plot_parameter_region(gj_forward_3_slope, ['lambda_1','lambda_2'], f=3/4, lambda_1=2/3, lambda_2=3/5) # not tested
    sage: plot_parameter_region(gj_forward_3_slope, ['lambda_1','lambda_2'], [3/5, 7/5], f=1/2, lambda_1=4/9, lambda_2=1/3) # not tested
    sage: plot_parameter_region(gj_forward_3_slope, ['lambda_1','lambda_2'], [9/10, 3/7], f=1/2, lambda_1=4/9, lambda_2=1/3) # not tested

    sage: plot_parameter_region(chen_4_slope, ['lam1', 'lam2'], [1/4, 1/4], plot_points=100) # not tested

    sage: plot_parameter_region(dg_2_step_mir, ['f','alpha'], [3/5,2/5-1/23],  plot_points=500) # not tested
    sage: plot_parameter_region(dg_2_step_mir_limit, ['f'], [8/13], d=2, plot_points=500) # not tested

    sage: plot_parameter_region(kf_n_step_mir, ['f'], [1/13], plot_points=100) # not tested
    """
    d = len(var_name)
    if d >= 3:
        #TODO
        raise NotImplementedError, "More than three parameters. Not implemented."
    region_type_color = {'is_minimal': 'green', 'not_minimal': 'darkslategrey', 'is_extreme': 'blue', 'not_extreme': 'cyan'}
    default_args = read_default_args(function, **opt_non_default)
    g = plot_region_according_to_literature(function, var_name, default_args, level=level, \
                                alpha=alpha, xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
    if not var_value:
        var_value = [default_args[v] for v in var_name]
    K, test_point = construct_field_and_test_point(function, var_name, var_value, default_args)
    try:
        h = function(**test_point)
        color_p = "white"
        region_type, leq, lin = find_region_around_given_point(K, h, level=level, region_level='minimal', \
                        is_minimal=None, use_simplified_extremality_test=use_simplified_extremality_test)
        g += plot_region_given_dim_and_description(d, (leq, lin), color=region_type_color[region_type], alpha=alpha, \
                        xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
        g += line([(0,0),(0,0.01)], color=region_type_color[region_type], legend_label=region_type, zorder=-10)
        if region_type == 'is_minimal':
            region_type, leq, lin = find_region_around_given_point(K, h, level=level, region_level='extreme', \
                            is_minimal=True, use_simplified_extremality_test=use_simplified_extremality_test)
            g += plot_region_given_dim_and_description(d, (leq, lin), color=region_type_color[region_type], alpha=alpha, \
                            xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points)
            g += line([(0,0),(0,0.01)], color=region_type_color[region_type], legend_label=region_type, zorder=-10)
    except:
        logging.warn("%s = %s is out of the constructible region." % (var_name, var_value))
        color_p = "black"
    if d == 2:
        p = point([var_value], color = color_p, size = 10, zorder=10)
        fun_param = "(%s=%s, %s=%s)" % (var_name[0], var_value[0], var_name[1], var_value[1])
    else:
        p = point([(var_value[0], 0)], color = color_p, size = 10, zorder=10)
        fun_param = "(%s=%s)" % (var_name[0], var_value[0])
    g += p

    fun_names = sage_getvariablename(function)
    i = 0
    while fun_names[i] == 'function':
        i += 1
    fun_name = fun_names[i]

    g.show(title=fun_name+fun_param) #show_legend=False, axes_labels=var_name)
    return g, fun_name, fun_param

###########################
# Randomly pick some points.
# Can their parameter regions cover the extreme region according to literature?
###########################

def cover_parameter_region(function=drlm_backward_3_slope, var_name=['f'], random_points=10, xmin=-0.1, xmax=1.1, ymin=-0.1, ymax=1.1, \
                            plot_points=0, show_points=2, regions=None, tested_points=None, **opt_non_default):
    """
    sage: regions, tested_points, last_n_points_was_covered = cover_parameter_region(gmic, ['f'], random_points=10, plot_points=100) # not tested
    sage: _ = cover_parameter_region(drlm_backward_3_slope, ['f','bkpt'], random_points=200, plot_points=500) # not tested
    sage: _ = cover_parameter_region(gj_2_slope, ['f', 'lambda_1'], 300, plot_points=100, show_points=1) # not tested

    sage: _ = cover_parameter_region(gj_forward_3_slope, ['lambda_1', 'lambda_2'], random_points=500, plot_points=500) # not tested
    sage: _ = cover_parameter_region(gj_forward_3_slope, ['f', 'lambda_1'], random_points=100, plot_points=500) # not tested

    sage: regions, tested_points, last_n_points_was_covered = cover_parameter_region(chen_4_slope, ['lam1', 'lam2'], 20, plot_points=0) # not tested
    sage: _ = cover_parameter_region(chen_4_slope, ['lam1', 'lam2'], 20, plot_points=500, show_points=1, regions=regions, tested_points=tested_points) # not tested
    """
    d = len(var_name)
    if d >= 3:
        #TODO
        raise NotImplementedError, "More than three parameters. Not implemented."
    default_args = read_default_args(function, **opt_non_default)
    if regions is None:
        regions = []
    if tested_points is None:
        tested_points = []
    last_n_points_were_covered = 0
    while random_points > 0:
        x, y = QQ(uniform(xmin, xmax)), QQ(uniform(ymin, ymax))
        if d == 2:
            var_value = [x, y]
        else:
            var_value = [x]
        # NOTE: When the function is not_constructible on this point,
        # it's costly to go through all the previously found regions and then return "point_is_covered=False"
        # So, first test if it's constructible
        K, test_point = construct_field_and_test_point(function, var_name, var_value, default_args)
        try:
            h = function(**test_point)
            # Function is contructible at this random point.
            tested_points.append((var_value, 'white'))
            random_points -= 1
            # Test if this point is already covered.
            point_is_covered = False
            for (region_type, leq, lin) in regions:
                if (d == 2) and all(l(x, y) == 0 for l in leq) and all(l(x, y) < 0 for l in lin) or \
                   (d == 1) and all(l(x) == 0 for l in leq) and all(l(x) < 0 for l in lin):
                    point_is_covered = True
                    break
            if point_is_covered:
                last_n_points_were_covered += 1
            else:
                region_type, leq, lin =  find_region_around_given_point(K, h, level="factor", region_level='extreme', \
                                                                is_minimal=None,use_simplified_extremality_test=True)
                regions.append((region_type, leq, lin))
                last_n_points_were_covered = 0
        except:
            # Function is not constructible at this random point.
            tested_points.append((var_value, 'black'))
    if plot_points > 0:
        g = plot_covered_regions(regions, tested_points, d=d, alpha=0.5, \
            xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax, plot_points=plot_points, show_points=show_points)
        fun_names = sage_getvariablename(function)
        i = 0
        while fun_names[i] == 'function':
            i += 1
        fun_name = fun_names[i]
        g.show(title=fun_name+'%s' % var_name)
    return regions, tested_points, last_n_points_were_covered


###########################
# Super class that stores the computation so far
###########################
class SemialgebraicComplexComponent(SageObject):

    def __init__(self, parent, K, var_value, region_type):
        self.parent = parent
        self.var_value = var_value
        self.region_type = region_type

        #note that self.polyhedron and K.polyhedron,
        # self.parent.monomial_list and K.monomial_list,
        # self.parent.v_dict and K.v_dict change simultaneously while lifting.
        self.polyhedron = K.polyhedron
        self.bounds, tightened_mip = self.bounds_propagation(self.parent.max_iter)
        if self.parent.max_iter == 0:
            tightened_mip = None

        self.leq, self.lin = read_leq_lin_from_polyhedron(self.polyhedron, \
                                                          self.parent.monomial_list, self.parent.v_dict, tightened_mip) #, check_variable_elimination=False)
        # self.pivot indicates the pivot variable for each equation of self.leq,
        # Compute it in self.generate_points_on_and_across_linear_wall()
        # where all walls are assumed to be linear (flip_ineq_step < 0).
        self.pivot = None 

    def bounds_propagation(self, max_iter):
        tightened_mip = construct_mip_of_nnc_polyhedron(self.polyhedron)
        # Compute LP bounds first
        bounds = [find_bounds_of_variable(tightened_mip, i) for i in range(len(self.parent.monomial_list))]

        bounds_propagation_iter = 0
        # TODO: single parameter polynomial_rational_flint object needs special treatment. ignore bounds propagation in this case for now.  #tightened = True
        tightened = bool(len(self.var_value) > 1)

        while bounds_propagation_iter < max_iter and tightened:
            bounds_propagation_iter += 1
            tightened = False
            # upward bounds propagation
            for i in range(len(self.var_value), len(self.parent.monomial_list)):
                m = self.parent.monomial_list[i] # m has degre >= 2
                if update_mccormicks_for_monomial(m, tightened_mip, self.polyhedron, \
                                                  self.parent.monomial_list, self.parent.v_dict, bounds):
                    tightened = True
            if tightened:
                tightened = False
                # downward bounds propagation
                for i in range(len(self.parent.monomial_list)):
                    (lb, ub) = bounds[i]
                    bounds[i] = find_bounds_of_variable(tightened_mip, i)
                    # Not sure about i < len(self.var_value) condition,
                    # but without it, bounds_propagation_iter >= max_iter is often attained.
                    #if (i < len(self.var_value)) and \
                    #   ((lb < bounds[i][0]) or (lb is None) and (bounds[i][0] is not None) or \
                    #    (bounds[i][1] < ub) or (ub is None) and (bounds[i][1] is not None)):
                    if (bounds[i][0] is not None) and ((lb is None) or (bounds[i][0] - lb > 0.001)) or \
                       (bounds[i][1] is not None) and ((ub is None) or (ub - bounds[i][1] > 0.001)):
                        tightened = True
            if bounds_propagation_iter >= max_iter:
                logging.warn("max number %s of bounds propagation iterations has attained." % max_iter)
        #print bounds_propagation_iter
        return bounds, tightened_mip

    def plot(self, alpha=0.5, plot_points=300, slice_value=None, show_testpoints=True):
        g = Graphics()
        if not slice_value:
            d = len(self.var_value)
            if d > 2:
                raise NotImplementedError, "Plotting region with dimension > 2 is not implemented. Provide `slice_value` to plot a slice of the region."
            leqs = self.leq
            lins = self.lin
            var_bounds = [bounds_for_plotting(self.bounds[i]) for i in range(d)]
        else:
            # assert (len(slice_value) == len(self.var_value))
            d = 0
            var_bounds = []
            for (i, z) in enumerate(slice_value):
                if z is None:
                    d += 1
                    var_bounds.append(bounds_for_plotting(self.bounds[i]))
                elif not is_value_in_interval(z, self.bounds[i]):
                    # empty slice
                    return g
            if d == 1:
                P.<unknown_x> = QQ[]
            elif d == 2:
                P.<unknown_x, unknown_y> = QQ[]
            else:
                raise NotImplementedError, "Plotting region with dimension > 2 is not implemented. Provide `slice_value` to plot a slice of the region."
            unknowns=iter(P.gens())
            parametric_point = [unknowns.next() if z is None else z for z in slice_value]
            leqs = []
            for leq in self.leq:
                l = leq(*parametric_point)
                if l in QQ:
                    if l != 0:
                        return g
                else:
                   leqs.append(l)
            lins = []
            for lin in self.lin:
                l = lin(*parametric_point)
                if l in QQ:
                    if l >= 0:
                        return g
                else:
                    lins.append(l)

        covered_type_color = {'not_constructible': 'white', 'not_minimal': 'orange', 'not_extreme': 'green', 'is_extreme': 'blue'}
        if self.region_type in covered_type_color.keys():
            innercolor = covered_type_color[self.region_type]
        else:
            innercolor = self.region_type
        if self.region_type == 'not_constructible':
            bordercolor = 'gray'
            ptcolor = 'black'
        else:
            bordercolor = innercolor
            ptcolor = 'white'

        x, y = var('x, y')

        if d == 2:
            if leqs or lins:
                g += region_plot([l(x, y) == 0 for l in leqs] + [l(x, y) < 0 for l in lins], \
                                 (x, var_bounds[0][0], var_bounds[0][1]), (y, var_bounds[1][0], var_bounds[1][1]), \
                                 incol=innercolor, alpha=alpha, plot_points=plot_points, bordercol=bordercolor)
            if show_testpoints and not slice_value:
                g += point(self.var_value, color = ptcolor, size = 2, zorder=10)
        else:
            if leqs or lins:
                g += region_plot([l(x) == 0 for l in leqs] + [l(x) < 0 for l in lins] + [y >= -0.01, y <= 0.01], \
                                 (x, var_bounds[0][0], var_bounds[0][1]), (y, -0.1, 0.3), \
                                 incol=innercolor, alpha=alpha, plot_points=plot_points, bordercol=bordercolor, ticks=[None,[]])
            if show_testpoints and not slice_value:
                g += point([self.var_value[0], 0], color = ptcolor, size = 2, zorder=10)
        return g

    def generate_one_point_by_flipping_inequality(self, ineq, adjustment=True, flip_ineq_step=0.01):
        ineq_gradient = gradient(ineq)
        current_point = vector([RR(x) for x in self.var_value]) # Real numbers, faster than QQ
        ineq_value = ineq(*current_point)
        while ineq_value <= 0:
            ineq_direction = vector([g(*current_point) for g in ineq_gradient])
            step_length = flip_ineq_step / (ineq_direction * ineq_direction) # ineq_value increases by flip_ineq_step=0.01 roughly
            if step_length > 1:
                step_length = 1  # ensure that distance of move <= sqrt(flip_ineq_step) = 0.1 in each step
            current_point += step_length * ineq_direction
            ineq_value = ineq(*current_point)
            #print current_point, RR(ineq_value)
        if adjustment:
            # experimental code, move along ineq=cste when more than one inequality are flipped.
            for l in self.lin:
                if l == ineq or l(*current_point) < 0:
                    continue
                #print "adjust ineq %s" % l
                l_gradient = gradient(l)
                l_value = l(*current_point)
                while l_value >= 0:
                    l_direction = vector([-g(*current_point) for g in l_gradient]) #decrease l_value
                    ineq_direction = vector([g(*current_point) for g in ineq_gradient])
                    s = (ineq_direction * l_direction) / (ineq_direction * ineq_direction)
                    if s == 0:
                        return None
                    projected_direction = l_direction - s * ineq_direction # want that ineq_value remains the same
                    step_length = flip_ineq_step / (projected_direction * l_direction) # l_value decreases by 0.01 roughly
                    # step_length = max(0.01, l_value) /(projected_direction * l_direction) # l_value decreases by 0.01 at least
                    #if l_direction * l_direction * 100 < 1:
                    #    step_length = 1 / sqrt(projected_direction * projected_direction * 100) # ensure distance of move < 0.1
                    if step_length * norm(projected_direction) >= 1:  # move too far  # is 1 a good value here??
                        return None
                    current_point += step_length * projected_direction
                    l_value = l(*current_point)
                    #print current_point, RR(l_value)
            for l in self.lin:
                if l == ineq:
                    if ineq(*current_point) <= 0:
                        return None
                else:
                    if l(*current_point) >= 0:
                        return None
        new_point = tuple(QQ(x) for x in current_point)
        return new_point #type is tuple

    def generate_points_on_and_across_linear_wall(self, ineq, flip_ineq_step=-1/100):
        variables = ineq.args()
        ineq_direction = vector(ineq.monomial_coefficient(v) for v in variables)
        # FIXME: Polynomial_rational_flint doesn't have .monomials() .monomial_coefficient
        ## ineq_gradient = gradient(ineq)
        ## # list of type MPolynomial_libsingular, but is constant by assumption.
        ## assert all((g in QQ) for g in ineq_gradient)
        ## ineq_direction = vector([QQ(g) for g in ineq_gradient])
        current_point = vector(self.var_value) # QQ, exact computation
        step_length =  - ineq(*current_point) / (ineq_direction * ineq_direction)
        current_point += step_length * ineq_direction

        # adjustment so that no other wall is acrossed.
        for l in self.lin:
            if l == ineq or l(*current_point) < 0:
                continue
            l_direction = vector(-l.monomial_coefficient(v) for v in variables)
            s = (ineq_direction * l_direction) / (ineq_direction * ineq_direction)
            projected_direction = l_direction - s * ineq_direction
            step_length = (l(*current_point)-flip_ineq_step) / (projected_direction * l_direction)
            current_point += step_length * projected_direction
        pt_on_wall = current_point

        step_length = min(-flip_ineq_step / (ineq_direction * ineq_direction), 1)
        current_point += step_length * ineq_direction
        for l in self.lin:
            if l == ineq or l(*current_point) < 0:
                continue
            l_direction = vector(-l.monomial_coefficient(v) for v in variables)
            s = (ineq_direction * l_direction) / (ineq_direction * ineq_direction)
            projected_direction = l_direction - s * ineq_direction
            step_length = (l(*current_point)-flip_ineq_step) / (projected_direction * l_direction)
            current_point += step_length * projected_direction
        pt_across_wall = current_point

        # find pivot for equations
        if self.pivot is None:
            self.pivot = find_pivot_variables(self.leq, self.lin)

        new_pt_on_wall = tuple(solve_for_pivot_variables(pt_on_wall, self.leq, self.pivot))
        new_pt_across_wall = tuple(solve_for_pivot_variables(pt_across_wall, self.leq, self.pivot))

        return (new_pt_on_wall, new_pt_across_wall) #type is tuple

    def generate_neighbour_points(self, flip_ineq_step=0.01):
        # See remark about flip_ineq_step in def add_new_component().
        neighbour_points = []
        for ineq in self.lin:
            if flip_ineq_step > 0:
                new_point = self.generate_one_point_by_flipping_inequality(ineq, flip_ineq_step=flip_ineq_step)
                if not new_point is None:
                    neighbour_points.append(new_point)
            elif flip_ineq_step < 0:
                # assumption: walls are linear
                (pt_on_wall, pt_across_wall) = self.generate_points_on_and_across_linear_wall(ineq, flip_ineq_step=flip_ineq_step)
                # question: always possilbe to across only one (linear) wall?
                neighbour_points.append(pt_on_wall)
                neighbour_points.append(pt_across_wall)
        return neighbour_points

class SemialgebraicComplex(SageObject):
    """
    EXAMPLES::

        sage: logging.disable(logging.WARN)    # Suppress output in automatic tests.
        sage: complex = SemialgebraicComplex(drlm_backward_3_slope, ['f','bkpt'])
        sage: complex.monomial_list
        [f, bkpt]

        First way of completing the graph is to shoot random points
        sage: complex.shoot_random_points(50)  # Got 17 components

        A better way is to use flipping inequality + bfs
        sage: complex.bfs_completion()             # not tested
        sage: g = complex.plot()                   # not tested
        sage: g.save("complex_drlm_backward_3_slope_f_bkpt.pdf") # not tested

        sage: complex = SemialgebraicComplex(gmic, ['f'])

        # Shooting random points
        sage: complex.shoot_random_points(50)    # not tested # Got 4 components
        # Flipping ineq bfs
        sage: complex.bfs_completion()           # not tested

        sage: complex = SemialgebraicComplex(gj_2_slope, ['f', 'lambda_1'])
        sage: complex.shoot_random_points(50)    # Got 18 components

        sage: complex = SemialgebraicComplex(chen_4_slope, ['lam1', 'lam2'])
        sage: complex.shoot_random_points(1000, var_bounds=[(0,1),(0,1)], max_failings=1000)  # not tested  #long time
        sage: complex.bfs_completion()           # not tested #long time

        Define var_bounds as a lambda function:

        sage: complex = SemialgebraicComplex(drlm_backward_3_slope, ['f','bkpt'])
        sage: var_bounds=[(0,1),((lambda x: x), (lambda x: 0.5+0.5*x))] # not tested
        sage: complex.shoot_random_points(50, var_bounds = var_bounds) # not tested
        #sage: complex.bfs_completion()           # not tested

        gj_forward_3_slope, choose the first 2 variables out of 3 as parameters,

        sage: complex = SemialgebraicComplex(gj_forward_3_slope, ['f', 'lambda_1'])
        sage: complex.shoot_random_points(100, max_failings=1000) # not tested
        sage: complex.bfs_completion()           # not tested
        sage: complex.plot(plot_points=500)      # not tested

        This can also obtained by specifying random points' var_bounds in 3d complex.

        sage: complex = SemialgebraicComplex(gj_forward_3_slope, ['f', 'lambda_1', 'lambda_2'])
        sage: complex.shoot_random_points(100, max_failings=1000, var_bounds = [(0,1), (0,1), (2/3, 2/3)]) # not tested
        sage: complex.plot(slice_value=[None, None, 2/3], restart=True) # not tested

        Compute 3-d complex, then take slice.

        sage: complex = SemialgebraicComplex(gj_forward_3_slope, ['f', 'lambda_1', 'lambda_2'])

        #sage: complex.shoot_random_points(500, max_failings=10000) # not tested
        sage: complex.plot(plot_points=500) # not tested
        sage: complex.plot(slice_value=[None, None, 2/3], restart=True, plot_points=500) # not tested
        sage: complex.plot(slice_value=[4/5, None, None], restart=True, plot_points=500) # not tested

        # more testcases in param_graphics.sage
    """

    def __init__(self, function, var_name, max_iter=8, **opt_non_default):
        #self.num_components = 0
        self.components = []

        self.function = function
        self.d = len(var_name)
        self.var_name = var_name
        self.default_args = read_default_args(function, **opt_non_default)

        self.monomial_list = []
        self.v_dict = {}
        K = SymbolicRealNumberField([0]*self.d, var_name)
        for i in range(self.d):
            v = K.gens()[i].sym().numerator()
            self.monomial_list.append(v)
            self.v_dict[v] = i
        self.graph = Graphics()
        self.num_plotted_components = 0
        self.points_to_test = set()
        self.max_iter = max_iter

    def generate_random_var_value(self, var_bounds=None):
        var_value = []
        for i in range(self.d):
            if not var_bounds:
                x = QQ(uniform(-0.1, 1.1))
            else:
                if hasattr(var_bounds[i][0], '__call__'):
                    l =  var_bounds[i][0](*var_value)
                else:
                    l = var_bounds[i][0]
                if hasattr(var_bounds[i][1], '__call__'):
                    u =  var_bounds[i][1](*var_value)
                else:
                    u = var_bounds[i][1]
                x = QQ(uniform(l, u))
            var_value.append(x)
        return var_value

    def is_point_covered(self, var_value):
        monomial_value = [m(var_value) for m in self.monomial_list]
        # coefficients in ppl point must be integers.
        lcm_monomial_value = lcm([x.denominator() for x in monomial_value])
        #print [x * lcm_monomial_value for x in monomial_value]
        pt = Generator.point(Linear_Expression([x * lcm_monomial_value for x in monomial_value], 0), lcm_monomial_value)
        for c in self.components:
            # Check if the random_point is contained in the box.
            if c.region_type == 'not_constructible' and c.leq == [] and c.lin == []:
                continue
            if is_point_in_box(monomial_value, c.bounds):
                # Check if all eqns/ineqs are satisfied.
                if c.polyhedron.relation_with(pt).implies(point_is_included):
                    return True
        return False
        
    def find_uncovered_random_point(self, var_bounds=None, max_failings=1000):
        num_failings = 0
        while not max_failings or num_failings < max_failings:
            if self.points_to_test:
                var_value = list(self.points_to_test.pop())
            else:
                var_value = self.generate_random_var_value(var_bounds=var_bounds)
            # This point is not already covered.
            if self.is_point_covered(var_value):
                num_failings += 1
            else:
                return var_value
        logging.warn("The graph has %s components. Cannot find one more uncovered point by shooting %s random points" % (len(self.components), max_failings))
        return False

    def add_new_component(self, var_value, flip_ineq_step=0):
        # Remark: the sign of flip_ineq_step indicates how to search for neighbour testpoints:
        # if flip_ineq_step = 0, don't search for neighbour testpoints. Used in shoot_random_points().
        # if flip_ineq_step < 0, we assume that the walls of the cell are linear eqn/ineq over original parameters.(So, gradient is constant; easy to find a new testpoint on the wall and another testpoint (-flip_ineq_step away) across the wall.) Used in bfs.
        # if flip_ineq_step > 0, we don't assume the walls are linear. Apply generate_one_point_by_flipping_inequality() with flip_ineq_step to find new testpoints across the wall only. Used in bfs.

        unlifted_space_dim =  len(self.monomial_list)
        K, test_point = construct_field_and_test_point(self.function, self.var_name, var_value, self.default_args)
        K.monomial_list = self.monomial_list # change simultaneously while lifting
        K.v_dict = self.v_dict # change simultaneously while lifting
        K.polyhedron.add_space_dimensions_and_embed(len(K.monomial_list))
        try:
            h = self.function(**test_point)
        except:
            # Function is non-contructible at this random point.
            h = None
        region_type =  find_region_type_around_given_point(K, h, region_level='extreme',
                                                           is_minimal=None,use_simplified_extremality_test=True)
        new_component = SemialgebraicComplexComponent(self, K, var_value, region_type)
        #if see new monomial, lift polyhedrons of the previously computed components.
        dim_to_add = len(self.monomial_list) - unlifted_space_dim
        if dim_to_add > 0:
            for c in self.components:
                c.polyhedron.add_space_dimensions_and_embed(dim_to_add)
        self.components.append(new_component)
        if (region_type != 'not_constructible') and (flip_ineq_step != 0):
            (self.points_to_test).update(new_component.generate_neighbour_points(flip_ineq_step))

    def shoot_random_points(self, num, var_bounds=None, max_failings=1000):
        for i in range(num):
            var_value = self.find_uncovered_random_point(var_bounds=var_bounds, max_failings=max_failings)
            if var_value is False:
                return
            else:
                self.add_new_component(var_value, flip_ineq_step=0)

    def plot(self, alpha=0.5, plot_points=300, slice_value=None, restart=False):
        if restart:
            self.graph = Graphics()
            self.num_plotted_components = 0
        for c in self.components[self.num_plotted_components::]:
            self.graph += c.plot(alpha=alpha, plot_points=plot_points, slice_value=slice_value)
        self.num_plotted_components = len(self.components)
        return self.graph

    def bfs_completion(self, var_value=None, var_bounds=None, max_failings=1000, flip_ineq_step=0.01):
        # See remark about flip_ineq_step in def add_new_component().
        # if var_value is provided, starting with this point. Otherwise, randomized the starting point.
        if not var_value:
            #var_value = self.generate_random_var_value(var_bounds=var_bounds)
            var_value = self.find_uncovered_random_point(var_bounds=var_bounds, max_failings=max_failings)
        (self.points_to_test).add(tuple(var_value))
        while self.points_to_test:
            var_value = list(self.points_to_test.pop())
            if not self.is_point_covered(var_value) and point_satisfies_var_bounds(var_value, var_bounds):
                self.add_new_component(var_value, flip_ineq_step=flip_ineq_step)

def gradient(ineq):
    # need this function since when K has only one variable,
    # got AttributeError: 'sage.rings.polynomial.polynomial_integer_dense_flint.Polynomial_integer_dense_flint' object has no attribute 'gradient'
    if hasattr(ineq, 'gradient'):
       return ineq.gradient()
    else:
       return [ineq.derivative()]

def point_satisfies_var_bounds(var_value, var_bounds):
    # for functions involving ceil/floor, might be a good to devide region of search, then glue components together.
    # var_bounds could be defined as lambda functions, see the testcase dg_2_step_mir in param_graphics.sage.
    if not var_bounds:
        return True
    for i in range(len(var_value)):
        if hasattr(var_bounds[i][0], '__call__'):
            l =  var_bounds[i][0](*var_value[0:i:1])
        else:
            l = var_bounds[i][0]
        if hasattr(var_bounds[i][1], '__call__'):
            u =  var_bounds[i][1](*var_value[0:i:1])
        else:
            u = var_bounds[i][1]
        if not (l <= var_value[i] <= u):
            return False
    return True

def is_value_in_interval(v, (lb, ub)):
    return ((lb is None) or (lb <= v)) and ((ub is None) or (v <= ub))

def is_point_in_box(monomial_value, bounds):
    # note: monomial_value can have length bigger than len(bounds),
    # just ignore the tailing monomial values which come from lifting.
    return all(is_value_in_interval(monomial_value[i], bounds[i]) for i in range(len(bounds)))

def bounds_for_plotting((lb, ub)):
    if not lb is None:
        l = lb - 0.01
    else:
        l = -0.1
    if not ub is None:
        u = ub + 0.01
    else:
        u = 1.1
    return (l, u)

def construct_mip_of_nnc_polyhedron(nncp):
    min_cs = nncp.minimized_constraints()
    cs = Constraint_System()
    for c in min_cs:
        if c.is_equality():
            cs.insert(Linear_Expression(c.coefficients(), c.inhomogeneous_term()) == 0)
        else:
            cs.insert(Linear_Expression(c.coefficients(), c.inhomogeneous_term()) >= 0)
    mip = MIP_Problem(nncp.space_dimension())
    mip.add_constraints(cs)
    mip.set_optimization_mode('minimization')
    return mip

def find_bounds_of_variable(mip, i):
    linexpr = Linear_Expression(Variable(i))
    lb = find_lower_bound_of_linexpr(mip, linexpr)
    ub = find_upper_bound_of_linexpr(mip, linexpr)
    return (lb, ub)

def find_lower_bound_of_linexpr(mip, linexpr):
    # assume mip.set_optimization_mode('minimization')
    mip.set_objective_function(linexpr)
    try:
        lb = mip.optimal_value()
    except:
        # unbounded
        lb = None
    return lb

def find_upper_bound_of_linexpr(mip, linexpr):
    # assume mip.set_optimization_mode('minimization')
    mip.set_objective_function(-linexpr)
    try:
        ub = -mip.optimal_value()
    except:
        # unbounded
        ub = None
    return ub

def is_not_a_downstairs_wall(c, mip):
    linexpr = Linear_Expression(c.coefficients(), c.inhomogeneous_term())
    # we know lb exists and is >= 0
    lb = find_lower_bound_of_linexpr(mip, linexpr)
    return bool(lb >  0)

def add_mccormick_bound(mip, x3, x1, x2, c1, c2, is_lowerbound):
    """
    Try adding x3 > c1*x1 + c2*x2 - c1*c2 (if is_lowerbound, else x3 < c1*x1 + c2*x2 - c1*c2 to mip. Return True this new constraint is not redundnant.
    """
    if c1 is None or c2 is None:
        # unbounded
        return False
    d = c1.denominator() * c2.denominator() #linear expression needs integer coefficients
    linexpr = Linear_Expression(d*x3 - d*c1*x1 - d*c2*x2 + d*c1*c2)
    if is_lowerbound:
        lb = find_lower_bound_of_linexpr(mip, linexpr)
        if (lb is not None) and (lb >= 0):
            return False
        else:
            mip.add_constraint(linexpr >= 0)
            return True
    else:
        ub = find_upper_bound_of_linexpr(mip, linexpr)
        if (ub is not None) and (ub <=0):
            return False
        else:
            mip.add_constraint(linexpr <= 0)
            return True

def update_mccormicks_for_monomial(m, tightened_mip, original_polyhedron, monomial_list, v_dict, bounds):
    # the argument original_polyhedron is not needed if we assume that
    # recursive McCormicks does not create new monomials.
    # Expect that the monomials in monomial_list have non-decreasing degrees.
    if m.degree() < 2:
        return False
    i = v_dict[m]
    v = Variable(i)
    tightened = False
    for v1 in m.variables():
        i_1 = v_dict[v1]
        v_1 = Variable(i_1)
        lb_1, ub_1 = bounds[i_1]

        v2 = (m/v1).numerator()
        if v2 in v_dict.keys():
            i_2 = v_dict[v2]
        else:
            logging.warn("new monomial %s is needed during recursive McCormick" % v2)
            i_2 = len(monomial_list)
            v_dict[v2]= i_2
            monomial_list.append(v2)
            original_polyhedron.add_space_dimensions_and_embed(1)
            tightened_mip.add_space_dimensions_and_embed(1)
            bounds.append((None, None))
            if update_mccormicks_for_monomial(v2, tightened_mip, original_polyhedron, \
                                              monomial_list, v_dict, bounds):
                tightened = True
        v_2 = Variable(i_2)
        lb_2, ub_2 = bounds[i_2]
        if add_mccormick_bound(tightened_mip, v, v_1, v_2, lb_2, lb_1, True):
            tightened = True
        if add_mccormick_bound(tightened_mip, v, v_1, v_2, ub_2, ub_1, True):
            tightened = True
        if add_mccormick_bound(tightened_mip, v, v_1, v_2, lb_2, ub_1, False):
            tightened = True
        if add_mccormick_bound(tightened_mip, v, v_1, v_2, ub_2, lb_1, False):
            tightened = True
        if m.degree() == 2:
            break
    if tightened:
        bounds[i] = find_bounds_of_variable(tightened_mip, i)
    return tightened

##############################
# linearly independent in Q
##############################
### Moved from parametric.sage to parametric_linear_independence.sage ###
