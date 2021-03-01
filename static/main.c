/* @Copyright 2021 Louis-Noel Pouchet <pouchet@colostate.edu> */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Global verbosity. 0 is quiet, 1-2 is normal, 10+ is debug, 20+ is high debug.
#define PERC_VERBOSE_LEVEL 5

// Globals to avoid excessive bufferization. Modify as needed.
#define PERC_MAX_STR_BUFFER_SIZE 1024
#define PERC_MAX_PROG_STR_BUFFER_SIZE 8192
#define PERC_MAX_AXIOMS_STR_BUFFER_SIZE 524288
#define PERC_MAX_NB_CHILDREN_PER_NODE_IN_PROGRAM 16
#define PERC_MAX_NB_AXIOMS 4096
#define PERC_MAX_NB_NODES 2048
#define PERC_MAX_PROOF_LENGTH 2048
#define PERC_MIN_AXIOMS_APPLICABLE 32

// Special const.
#define PERC_NODE_TYPE_SUBTREE 0

//#define PERC_MAX_NB_REWRITE_TRIALS 4096
#define PERC_MAX_NB_REWRITE_TRIALS 4


#define debug_message(level, ...) { if (PERC_VERBOSE_LEVEL >= level) fprintf (stdout, __VA_ARGS__); }
#define debug_call(level, ...) { if (PERC_VERBOSE_LEVEL >= level) { __VA_ARGS__; } }
#define error_message(errcode, ...) { fprintf (stderr, __VA_ARGS__); exit (errcode); }
#define error_call(level, ...) { { __VA_ARGS__; } exit (level); }

#define XMALLOC(sz) xmalloc(sz)
#define XREALLOC(ptr,sz) xrelloc(ptr,sz)
#define XFREE(ptr) xfree(ptr)

void* xmalloc(size_t sz)
{
  void* ret = malloc (sz);
  if (ret != NULL)
    return ret;
  error_message(1, "[PERC] Memory exhausted\n");
}

void* xrelloc(void* ptr, size_t sz)
{
  void* ret = realloc (ptr, sz);
  if (ret != NULL)
    return ret;
  error_message(1, "[PERC] Memory exhausted\n");
}

int xfree(void* ptr)
{
  if (ptr) {
    free (ptr);
    return 0;
  }
  return 1;
}

/* enum e_nodetypes */
/* { */
/*  root		 = 1, */
/*  scal_add	 = 2, */
/*  scal_mul	 = 3, */
/*  scal_var	 = 4, */
/*  scal_cst	 = 5, */
/*  scal_zero	 = 6, */
/*  scal_one	 = 7, */

/* }; */
/* typedef enum e_nodetypes e_nodetypes_t; */

struct s_node_type_info
{
  int		uid;
  char*		print_string;
  char*		parse_string;
  int		nb_children;
};
typedef struct s_node_type_info s_node_type_info_t;

struct s_node_types
{
  int			nb_types;
  s_node_type_info_t*	types;
};
typedef struct s_node_types s_node_types_t;

void perc_node_type_print(FILE* output,
			  s_node_type_info_t* types,
			  s_node_type_info_t* node_type)
{
  if (node_type == NULL)
    error_message(1, "[PERC] Unknown type (NULL)\n");
  fprintf (output, "%s", node_type->print_string);
}

void perc_node_type_print_from_uid(FILE* output,
				   s_node_type_info_t* types,
				   int uid)
{
  int i;
  for (i = 0; types && types[i].uid != -1; ++i);
  if (uid >= i - 1)
    error_message(1, "[PERC] Unknown type uid\n");
  fprintf (output, "%s", types[uid].print_string);
}

typedef struct s_axiom* s_axiom_p;
struct s_node
{
  int			uid;
  /* e_nodetypes_t		type; */
  s_node_type_info_t*	type;
  char*			parse_token;
  char*			token;
  void*			value;
  void*			usr;

  int			nb_axioms_applicable;
  s_axiom_p*		axioms_applicable;
  size_t		axioms_applicable_buffersize;

  struct s_node*	parent;
  int			nb_children;
  struct s_node*	children[PERC_MAX_NB_CHILDREN_PER_NODE_IN_PROGRAM];
				// Systematically max out to 16 children.
				// Use more space, but avoids allocations.
};
typedef struct s_node s_node_t;
typedef s_node_t* s_node_p;

s_node_p perc_node_malloc()
{
  s_node_p ret = XMALLOC(sizeof(s_node_t));
  ret->uid = -1;
  ret->type = NULL;
  ret->parse_token = NULL;
  ret->token = NULL;
  ret->value = NULL;
  ret->usr = NULL;
  ret->parent = NULL;
  ret->nb_children = 0;
  ret->nb_axioms_applicable = 0;
  ret->axioms_applicable =
    XMALLOC(PERC_MIN_AXIOMS_APPLICABLE * sizeof(s_axiom_p));
  ret->axioms_applicable_buffersize = PERC_MIN_AXIOMS_APPLICABLE;

  return ret;
}

int perc_node_free(s_node_p p)
{
  if (!p)
    return 1;
  XFREE(p->parse_token);
  XFREE(p->token);
  XFREE(p->axioms_applicable);
  XFREE(p);
  return 0;
}


s_node_p perc_node_clone(s_node_p n)
{
  s_node_p ret = perc_node_malloc ();
  ret->uid = n->uid;
  ret->type = n->type;
  ret->parse_token = strdup (n->parse_token);
  ret->token = strdup (n->token);
  ret->value = n->value;
  ret->usr = n->usr;
  ret->parent = NULL;
  ret->nb_children = 0;
  ret->nb_axioms_applicable = n->nb_axioms_applicable;
  int i;
  ret->axioms_applicable =
    XMALLOC(ret->axioms_applicable_buffersize * sizeof(s_axiom_p));
  for (i = 0; i < n->nb_axioms_applicable; ++i)
    ret->axioms_applicable[i] = n->axioms_applicable[i];
  return ret;
}

s_node_p perc_tree_clone(s_node_p n)
{
  if (!n)
    return NULL;
  s_node_p newnode = perc_node_clone (n);
  newnode->nb_children = n->nb_children;
  int i;
  for (i = 0; i < n->nb_children; ++i)
    {
      newnode->children[i] = perc_tree_clone (n->children[i]);
      newnode->children[i]->parent = newnode;
    }
  return newnode;
}


int perc_tree_replace_node (s_node_p n,
			    s_node_p repl)
{
  if (!n)
    return 1;
  s_node_p parent = n->parent;
  int i;
  for (i = 0; i < parent->nb_children && parent->children[i] != n; ++i)
    ;
  parent->children[i] = repl;
  repl->parent = parent;
}


int perc_node_is_subtree_type(s_node_p n)
{
  return n->type->uid == PERC_NODE_TYPE_SUBTREE;
}


struct s_program
{
  s_node_p		root;
  int			nb_nodes;
  s_node_p*		dfs_nodes;  // DFS representation of the tree
};
typedef struct s_program s_program_t;
typedef s_program_t* s_program_p;


s_program_p perc_program_malloc()
{
  s_program_p ret = XMALLOC(sizeof(s_program_t));
  ret->root = NULL;
  ret->nb_nodes = 0;
  ret->dfs_nodes = NULL;

  return ret;
}

int perc_program_free(s_program_p p)
{
  XFREE(p);
}

static
char* _read_op_token(char** str)
{
  if (! *str)
    return NULL;

  char buffer[PERC_MAX_STR_BUFFER_SIZE];
  int pos = 0;

  // Eliminate comments.
  if (**str == '#')
    {
      while (**str && **str != '\n')
	(*str)++;
      (*str)++;
    }

  // Eliminate whitespaces, closing parenthesis and EOL.
  while (**str && (**str == ' ' || **str == '\t' ||
		   **str == ')' || **str == '\n'))
    (*str)++;
  // Get token, separated by '(', ')' or ','
  while (**str && **str != '(' && **str != ')' && **str != ',')
    {
      buffer[pos++] = **str;
      (*str)++;
    }
  while (**str && (**str == '(' || **str == ','))
    (*str)++;
  buffer[pos] = '\0';
  // Eliminate whitespaces, closing parenthesis and ','
  while (**str && (**str == ' ' || **str == '\t' ||
		   **str == ')' || **str == ','))
    (*str)++;

  return strdup (buffer);
}

static
s_node_type_info_t*
_find_node_type_from_parse_string(s_node_type_info_t* node_types,
				  char* op_token)
{
  int i;
  for (i = 0; node_types && node_types[i].uid != -1; ++i)
    if (! strncmp (op_token, node_types[i].parse_string,
		   strlen (node_types[i].parse_string)))
      return &(node_types[i]);
  error_message(1, "[PERC] Error at parsing: token %s is not recognized\n",
		op_token);
  return NULL;
}

static
char* _get_base_token_without_type(char* str)
{
  if (! str)
    return NULL;

  char buffer[PERC_MAX_STR_BUFFER_SIZE];
  int pos = 0;
  while (*str && *str != '_')
    str++;
  if (! *str)
    return NULL;
  str++;
  while (*str)
    buffer[pos++] = *(str++);
  buffer[pos] = '\0';
  return strdup (buffer);
}

static
s_node_p _perc_program_parse_rec(char** str,
				 s_node_p parent,
				 s_node_type_info_t* node_types)
{
  // Done parsing.
  if (!str || !*str || **str == '\0')
    return NULL;
  char* op_token = _read_op_token (str);
  debug_message(20, "op_token: |%s|\n", op_token);
  // Got empty token, end of parsing.
  if (! op_token || op_token[0] == '\0')
    return NULL;
  s_node_type_info_t* node_type =
    _find_node_type_from_parse_string (node_types, op_token);
  if (node_type == NULL)
    return NULL;
  s_node_p node = perc_node_malloc ();
  node->parent = parent;
  node->parse_token = op_token;
  node->token = _get_base_token_without_type (op_token);
  if (! node->token || ! node->token[0])
    node->token = strdup (node->parse_token);
  node->value = op_token;
  node->type = node_type;
  if (perc_node_is_subtree_type (node))
    node->value = (void*) (long int) atoi (node->token);
  int nb_children = node_type->nb_children;
  if (node_type->nb_children == -1)
    nb_children = PERC_MAX_NB_CHILDREN_PER_NODE_IN_PROGRAM;
  int i;
  for (i = 0; i < nb_children; ++i)
    {
      node->children[i] = _perc_program_parse_rec (str, node, node_types);
      if (node->children[i])
	node->nb_children++;
    }

  return node;
}


typedef void (*s_tree_visitor_ptr_fun_t)(s_node_p, void**);

static
void _func_count_nodes(s_node_p n, void** args)
{
  n->uid = (*(int*)(args[0]))++;
}

static
void _func_build_prefix_list(s_node_p n, void** args)
{
  s_node_p** nodes = args[0];
  (*nodes)[n->uid] = n;
}


static
void _tree_traversal(s_node_p n, void** args,
		     s_tree_visitor_ptr_fun_t f_prefix,
		     s_tree_visitor_ptr_fun_t f_infix,
		     s_tree_visitor_ptr_fun_t f_suffix)
{
  if (! n)
    return;
  if (f_prefix)
    f_prefix (n, args);
  int i;
  for (i = 0; i < n->nb_children; ++i)
    {
      _tree_traversal (n->children[i], args, f_prefix, f_infix, f_suffix);
      if (i < n->nb_children - 1 && f_infix)
	f_infix (n, args);
    }
  if (f_suffix)
    f_suffix (n, args);
}

static
void _prefix_tree_traversal(s_node_p n, void** args,
			    s_tree_visitor_ptr_fun_t f_prefix)
{
  _tree_traversal (n, args, f_prefix, NULL, NULL);
}


static
void perc_tree_traversal_prefix(s_node_p n, void** args,
				s_tree_visitor_ptr_fun_t f_prefix)
{
  _tree_traversal (n, args, f_prefix, NULL, NULL);
}

static
void perc_tree_traversal_postfix(s_node_p n, void** args,
				 s_tree_visitor_ptr_fun_t f_postfix)
{
  _tree_traversal (n, args, NULL, NULL, f_postfix);
}



s_program_p perc_program_read_from_file(char* filename,
					s_node_type_info_t* node_types)
{
  s_program_p ret = perc_program_malloc ();
  // Read from file.
  FILE* f = fopen (filename, "r");
  if (f == NULL)
    error_message(1, "[PERC] File %s does not exist.\n", filename);
  char* program_str = XMALLOC(PERC_MAX_PROG_STR_BUFFER_SIZE * sizeof(char));
  fread (program_str, sizeof(char), PERC_MAX_PROG_STR_BUFFER_SIZE - 1, f);
  fclose (f);
  debug_message(10, "[PERC] Input program string: %s\n", program_str);
  // Parse.
  char* prog_str = program_str;
  s_node_p root = _perc_program_parse_rec(&program_str, NULL, node_types);
  XFREE(prog_str);
  // Format output.
  ret->root = root;
  void* args1[] = { &(ret->nb_nodes) };
  _prefix_tree_traversal (root, args1, _func_count_nodes);
  ret->dfs_nodes = XMALLOC(sizeof(s_node_p) * ret->nb_nodes);
  int uid = 0;
  void* args2[] = { &(ret->dfs_nodes), &uid };
  _prefix_tree_traversal (root, args2, _func_build_prefix_list);
  debug_message(20, "number of nodes: %d\n", ret->nb_nodes);

  return ret;
}

// Prefix print.
static
void _perc_program_print_rec(FILE* output,
			     s_node_p n,
			     s_node_type_info_t* node_types,
			     int indent)
{
  if (n == NULL)
    return;

  int i;
  for (i = 0; i < indent; ++i)
    fprintf (output, " ");
  fprintf (output, " + ");
  perc_node_type_print (output, node_types, n->type);
  if (n->token)
    fprintf (output, " (tok=%s,uid=%d)\n", n->token, n->uid);
  else
    fprintf (output, " \n");
  for (i = 0; i < n->nb_children; ++i)
    _perc_program_print_rec (output, n->children[i], node_types, indent + 2);
}


void perc_program_print(FILE* output,
			s_program_p p,
			s_node_type_info_t* node_types)
{
  debug_message(20, "[PERC] Printing program:\n");
  _perc_program_print_rec (output, p->root, node_types, 0);
}


int perc_program_check_identical(s_program_p p1, s_program_p p2)
{
  if (p1->nb_nodes != p2->nb_nodes)
    return 0;
  int i;
  for (i = 0; i < p1->nb_nodes; i++)
    if (p1->dfs_nodes[i]->type != p2->dfs_nodes[i]->type ||
	strcmp (p1->dfs_nodes[i]->token, p2->dfs_nodes[i]->token))
      return 0;
  return 1;
}


int perc_program_update_representation(s_program_p p)
{
  if (!p)
    return 1;
  if (p->root == NULL)
    {
      XFREE(p->dfs_nodes);
      p->nb_nodes = 0;
      return 0;
    }
  XFREE(p->dfs_nodes);
  p->nb_nodes = 0;
  void* args1[] = { &(p->nb_nodes) };
  _prefix_tree_traversal (p->root, args1, _func_count_nodes);
  p->dfs_nodes = XMALLOC(sizeof(s_node_p) * p->nb_nodes);
  int uid = 0;
  void* args2[] = { &(p->dfs_nodes), &uid };
  _prefix_tree_traversal (p->root, args2, _func_build_prefix_list);
  return 0;
}

s_program_p perc_program_from_tree(s_node_p n)
{
  s_program_p ret = perc_program_malloc ();
  ret->root = n;
  perc_program_update_representation (ret);
  return ret;
}


struct s_axiom
{
  int		uid;
  s_program_p	input_match;
  s_program_p	rewrite;
  char*		match_string;
  char*		rewrite_string;
};
typedef struct s_axiom s_axiom_t;
typedef s_axiom_t* s_axiom_p;

s_axiom_p perc_axiom_malloc()
{
  s_axiom_p ret = XMALLOC(sizeof(s_axiom_t));

  ret->uid = 0;
  ret->input_match = NULL;
  ret->rewrite = NULL;
  ret->match_string = NULL;
  ret->rewrite_string = NULL;
  return ret;
}

int perc_axiom_free(s_axiom_p a)
{
  if (!a)
    return 1;
  perc_program_free (a->input_match);
  perc_program_free (a->rewrite);
  XFREE(a->match_string);
  XFREE(a->rewrite_string);
  XFREE(a);
  return 0;
}

struct s_axioms
{
  int		nb_axioms;
  s_axiom_p*	axioms_list;
};
typedef struct s_axioms s_axioms_t;
typedef s_axioms_t* s_axioms_p;

s_axioms_p perc_axioms_malloc()
{
  s_axioms_p ret = XMALLOC(sizeof(s_axioms_t));
  ret->nb_axioms = 0;
  ret->axioms_list = NULL;

  return ret;
}

int perc_axioms_free(s_axioms_p a)
{
  if (!a)
    return 1;
  int i;
  for (i = 0; a->axioms_list && i < a->nb_axioms; ++i)
    perc_axiom_free (a->axioms_list[i]);
  XFREE(a);
  return 0;
}

s_axioms_p perc_axioms_read_from_file(char* filename,
				      s_node_type_info_t* node_types)
{
  s_axioms_p ret = perc_axioms_malloc ();
  ret->axioms_list = XMALLOC(PERC_MAX_NB_AXIOMS * sizeof(s_axiom_p));

/* @s+(M_A,M_B);@s+(M_B,M_A) */
/* @s*(M_A,@s+(M_B,M_C));@s+(@s*(M_A,M_B),@s*(M_A,M_C)) */

  // Read from file.
  FILE* f = fopen (filename, "r");
  if (f == NULL)
    error_message(1, "[PERC] File %s does not exist.\n", filename);
  char* program_str = XMALLOC(PERC_MAX_AXIOMS_STR_BUFFER_SIZE * sizeof(char));
  fread (program_str, sizeof(char), PERC_MAX_AXIOMS_STR_BUFFER_SIZE - 1, f);
  fclose (f);
  debug_message(10, "[PERC] Input axioms string: %s\n", program_str);
  // Parse.
  char* prog_str = program_str;
  char* buffer = XMALLOC(PERC_MAX_PROG_STR_BUFFER_SIZE * sizeof(char));
  char* buffer_ptr = buffer;
  int axioms_count = 0;
  while (*program_str)
    {
      int pos = 0;
      char* base = program_str;
      while (*program_str && (*program_str == ' ' || *program_str == '\t' ||
			      *program_str == '\n'))
	program_str++;
      // Eliminate comments.
      if (*program_str == '#')
	{
	  while (*program_str && *program_str != '\n')
	    program_str++;
	  program_str++;
	  continue;
	}
      if (! *program_str)
	break;
      // Go for first program/input match:
      while (*program_str && *program_str != ';' && *program_str != '\n')
	buffer[pos++] = *(program_str++);
      buffer[pos] = '\0';
      debug_message(20, "axiom-match: |%s|\n", buffer);
      if (*program_str != ';')
	error_message(1, "[PERC] Error in axioms: %s is incomplete\n", buffer);
      program_str++;
      char* match_string = strdup (buffer);
      char* buf_ptr = buffer;
      s_node_p match = _perc_program_parse_rec(&buf_ptr, NULL, node_types);
      buffer = buf_ptr;
      if (!match)
	error_message(1, "[PERC] Error in axioms: %s is invalid\n", buffer);
      pos = 0;
      // Go for second program/rewrite rule:
      while (*program_str && *program_str != ';' && *program_str != '\n')
	buffer[pos++] = *(program_str++);
      buffer[pos] = '\0';
      debug_message(20, "axiom-rewrite: |%s|\n", buffer);
      char* rewrite_string = strdup (buffer);
      buf_ptr = buffer;
      s_node_p rewrite = _perc_program_parse_rec(&buf_ptr, NULL, node_types);
      buffer = buf_ptr;
      if (!rewrite)
	error_message(1, "[PERC] Error in axioms: %s is invalid\n", buffer);
      if (*program_str != '\n' && *program_str)
	error_message(1, "[PERC] Error in axioms: %s is incomplete\n", buffer);
      if (*program_str)
	program_str++;
      // Build axiom.
      s_axiom_p axiom = perc_axiom_malloc ();
      axiom->input_match = perc_program_from_tree (match);
      axiom->rewrite = perc_program_from_tree (rewrite);
      axiom->uid = axioms_count++;
      ret->axioms_list[ret->nb_axioms++] = axiom;
      axiom->match_string = match_string;
      axiom->rewrite_string = rewrite_string;
      if (ret->nb_axioms >= PERC_MAX_NB_AXIOMS)
	error_message(1, "[PERC] Maximum number of axioms: %d\n",
		      PERC_MAX_NB_AXIOMS);
    }
  XFREE(prog_str);
  XFREE(buffer_ptr);
  ret->axioms_list = XREALLOC(ret->axioms_list,
			      ret->nb_axioms * sizeof(s_axiom_p));

  return ret;
}


void perc_axioms_print(FILE* output, s_axioms_p axioms,
		       s_node_type_info_t* node_types)
{
  if (!axioms)
    return;
  int i;
  for (i = 0; i < axioms->nb_axioms; ++i)
    {
      fprintf (output, "Axiom ID %d: match\n", axioms->axioms_list[i]->uid);
      perc_program_print (output, axioms->axioms_list[i]->input_match,
			  node_types);
      fprintf (output, "rewrite to\n");
      perc_program_print (output, axioms->axioms_list[i]->rewrite,
			  node_types);
    }
}


struct s_proof_step
{
  s_axiom_p	axiom;
  s_node_p	node;

};
typedef struct s_proof_step s_proof_step_t;
typedef s_proof_step_t* s_proof_step_p;

struct s_proof
{
		// store uid of axiom, uid of application_node:
  int		proof_steps[PERC_MAX_PROOF_LENGTH][2];
  int		nb_steps;
  int		is_valid;
};
typedef struct s_proof s_proof_t;
typedef s_proof_t* s_proof_p;

s_proof_p perc_proof_malloc()
{
  s_proof_p ret = XMALLOC(sizeof(s_proof_t));
  ret->nb_steps = 0;
  ret->is_valid = 0;
  return ret;
}

int perc_proof_free(s_proof_p p)
{
  XFREE(p);
}

void _find_first_node_with_axiom_applicable(s_node_p n, void** args)
{
  if (n && n->nb_axioms_applicable > 0)
    {
      s_node_p* dest = args[0];
      if (*dest == NULL)
	*dest = n;
    }
}


int perc_program_tree_check_axiom_is_applicable_at_node(s_node_p n,
							s_axiom_p axiom)
{
/* @s+(M_A,M_B);@s+(M_B,M_A) */
/* @s*(M_A,@s+(M_B,M_C));@s+(@s*(M_A,M_B),@s*(M_A,M_C)) */

  // Match by BFS. Interesting idea: create a combined prefix+postfix
  // ordering. We can distinguish subtree by taking the sequence in
  // between 2 occurence of the same node id.
  s_node_p queue1[PERC_MAX_NB_NODES];
  s_node_p queue2[PERC_MAX_NB_NODES];
  int queue1_start = 0;
  int queue2_start = 0;
  int queue1_top = 0;
  int queue2_top = 0;
  s_node_p axiom_root = axiom->input_match->root;
  queue1[queue1_top++] = axiom_root;
  queue2[queue2_top++] = n;
  while (queue1_start < queue1_top &&
	 queue2_start < queue2_top)
    {
      s_node_p axn = queue1[queue1_start++];
      s_node_p prn = queue2[queue2_start++];
      if (perc_node_is_subtree_type (axn))
	continue;
      if (axn->type != prn->type ||
	  strcmp (axn->token, prn->token))
	return 0;
      int i;
      for (i = 0; i < axn->nb_children; ++i)
	queue1[queue1_top++] = axn->children[i];
      for (i = 0; i < prn->nb_children; ++i)
	queue2[queue2_top++] = prn->children[i];
    }

  return 1;
}




void _compute_axioms_applicable(s_node_p n, void** args)
{
  if (!n)
    return;
  s_axioms_p axioms = args[0];
  if (! axioms)
    return;
  int i;
  for (i = 0; i < axioms->nb_axioms; ++i)
    {
      if (perc_program_tree_check_axiom_is_applicable_at_node
	  (n, axioms->axioms_list[i]))
	{
	  debug_message(20, "found axiom applicable: a-uid:%d on node n-uid:%d\n", i, n->uid);
	  if (n->nb_axioms_applicable >= n->axioms_applicable_buffersize)
	    {
	      n->axioms_applicable_buffersize += PERC_MIN_AXIOMS_APPLICABLE;
	      n->axioms_applicable =
		XREALLOC(n->axioms_applicable,
			 n->axioms_applicable_buffersize * sizeof(s_axiom_p));
	      debug_message(20, "realloc to %d for axioms_applicable\n",
			    n->axioms_applicable_buffersize);
	    }
	  n->axioms_applicable[n->nb_axioms_applicable++] =
	    axioms->axioms_list[i];
	}
    }
}

void perc_program_label_applicable_axioms(s_node_p n, s_axioms_p axioms)
{
  void* args[] = { axioms };
  perc_tree_traversal_prefix(n, args,
			     _compute_axioms_applicable);
}


static
void _replace_fillers_by_subtrees(s_node_p n, void** args)
{
  s_node_p* subtrees = *args;
  if (perc_node_is_subtree_type (n))
    perc_tree_replace_node (n, subtrees[(long int)n->value]);
}


s_program_p perc_program_rewrite(s_program_p prog,
				 s_axiom_p axiom,
				 s_node_p application_node)
{

  // Rewrite by BFS. Be lazy... should be collected during matching instead.
  s_node_p queue1[PERC_MAX_NB_NODES];
  s_node_p queue2[PERC_MAX_NB_NODES];
  s_node_p subtrees[PERC_MAX_NB_NODES];
  s_node_p to_delete[PERC_MAX_NB_NODES];
  int subtree_pos = 0;
  int to_delete_pos = 0;
  int queue1_start = 0;
  int queue2_start = 0;
  int queue1_top = 0;
  int queue2_top = 0;
  s_node_p axiom_root = axiom->input_match->root;
  queue1[queue1_top++] = axiom_root;
  queue2[queue2_top++] = application_node;
  while (queue1_start < queue1_top &&
  	 queue2_start < queue2_top)
    {
      s_node_p axn = queue1[queue1_start++];
      s_node_p prn = queue2[queue2_start++];
      if (perc_node_is_subtree_type (axn))
	{
	  subtrees[subtree_pos++] = prn;
	  continue;
	}
      to_delete[to_delete_pos++] = prn;
      int i;
      for (i = 0; i < axn->nb_children; ++i)
  	queue1[queue1_top++] = axn->children[i];
      for (i = 0; i < prn->nb_children; ++i)
  	queue2[queue2_top++] = prn->children[i];
    }

  //
  s_node_p new_subtree = perc_tree_clone (axiom->rewrite->root);
  void* args = (void*)subtrees;
  perc_tree_traversal_prefix (new_subtree, &args, _replace_fillers_by_subtrees);
  new_subtree->parent = application_node->parent;
  perc_tree_replace_node (application_node, new_subtree);
  int i;
  for (i = 0; i < to_delete_pos; ++i)
    perc_node_free (to_delete[i]);

  perc_program_update_representation (prog);

  return prog;
}


s_proof_p perc_proof_compute_smarter(s_program_p p1, s_program_p p2,
				     s_axioms_p axioms,
				     s_node_type_info_t* node_types)
{
  /// TBD!
  return NULL;
}


/// Stupid proof-of-concept: compute axioms applicables everywhere on
/// p2 (annotating the tree), then... pick the first node and first
/// axiom for it in dfs order, without consideration for applying it
/// multiple times...
s_proof_p perc_proof_compute_naive(s_program_p p1, s_program_p p2,
				   s_axioms_p axioms,
				   s_node_type_info_t* node_types)
{
  s_proof_p proof = perc_proof_malloc ();

  s_program_p ptemp = p2;
  int number_rewrites_trials = 0;

  while (! perc_program_check_identical (p1, ptemp) &&
	 number_rewrites_trials < PERC_MAX_NB_REWRITE_TRIALS)
    {
      ++number_rewrites_trials;

      debug_message(10, "[PERC] Trying rewrite #%d\n", number_rewrites_trials);

      perc_program_label_applicable_axioms (ptemp->root, axioms);
      s_node_p application_node = NULL;
      void* args[] = { &application_node };
      perc_tree_traversal_prefix(ptemp->root, args,
				 _find_first_node_with_axiom_applicable);
      // Something weird happened: no axiom can be applied. Still continue.
      if (application_node == NULL)
	{
	  debug_message(20, "could not find application node\n");
	  continue;
	}
      // Take the first applicable axiom (trial for the moment).
      s_axiom_p axiom = application_node->axioms_applicable[0];
      // Store the current proof.
      proof->proof_steps[proof->nb_steps][0] = axiom->uid;
      proof->proof_steps[proof->nb_steps++][1] = application_node->uid;

      debug_message(20, "Axiom to be applied: UID: %d on node uid %d\n",
		    axiom->uid, application_node->uid);
      debug_message(20, "program before rewrite:\n");
      debug_call(20, perc_program_print (stdout, ptemp, node_types));
      // Rewrite p2.
      ptemp = perc_program_rewrite (ptemp, axiom, application_node);

      debug_message(20, "program AFTER rewrite:\n");
      debug_call(20, perc_program_print (stdout, ptemp, node_types));

    }
  if (number_rewrites_trials < PERC_MAX_NB_REWRITE_TRIALS)
    {
      debug_message(0,
	 "[PERC][Proof] The following programs are structurally equal:\n");
      perc_program_print (stdout, p1, node_types);
      perc_program_print (stdout, p2, node_types);
      proof->is_valid = 1;
    }
  return proof;
}

void perc_proof_print(FILE* output, s_proof_p proof, s_axioms_p axioms)
{
  if (!proof)
    {
      debug_message(0, "[PERC] Empty proof/no proof was found\n");
      return;
    }
  if (proof->is_valid)
    { debug_message(0, "[PERC] Proof steps (valid):\n" ); }
  else
    { debug_message(0, "[PERC] Steps attempted (invalid/incomplete proof):\n");}
  int i;
  for (i = 0; i < proof->nb_steps; ++i)
    debug_message(0, "%d:\tAxiom #%d: |%s|=>|%s| applied to node %d\n", i + 1,
		  proof->proof_steps[i][0],
		  axioms->axioms_list[proof->proof_steps[i][0]]->match_string,
		  axioms->axioms_list[proof->proof_steps[i][0]]->rewrite_string,
		  proof->proof_steps[i][1]);
}


int main(int argc, char** argv)
{
  debug_message(1, "[PERC] Starting...\n");

  s_node_type_info_t node_types[] =
    {
     // Special node type for subtrees.
     { 0, "subtree", "M_", 0 }, // UID must match #define PERC_NODE_TYPE_SUBTREE

     // Regular nodes. Extend as needed.
     { 1, "root", "@R", -1 },
     { 2, "scalar_add", "@s+", 2 },
     { 3, "scalar_mul", "@s*", 2 },
     { 4, "scalar_var", "S_", 0 },
     { 5, "scalar_val", "s_", 0 },
     { 6, "scalar_zero", "s0", 0 },

     // Special terminator for node types.
     { -1, "terminator", "", 0 }
  };

  s_program_p p1 = perc_program_read_from_file (argv[1], node_types);
  s_program_p p2 = perc_program_read_from_file (argv[2], node_types);
  s_axioms_p axioms = perc_axioms_read_from_file (argv[3], node_types);
  if (PERC_VERBOSE_LEVEL > 0)
    {
      debug_message(1, "[PERC] Program P1:\n");
      perc_program_print (stdout, p1, node_types);
      debug_message(1, "[PERC] Program P2:\n");
      perc_program_print (stdout, p2, node_types);
      debug_message(1, "[PERC] Axiom system:\n");
      perc_axioms_print (stdout, axioms, node_types);
    }

  s_proof_p proof = perc_proof_compute_naive (p1, p2, axioms, node_types);
  perc_proof_print (stdout, proof, axioms);

  // Be clean.
  perc_proof_free (proof);
  perc_program_free (p1);
  perc_program_free (p2);
  perc_axioms_free (axioms);

  debug_message(1, "[PERC] All done\n");
  return 0;
}
